# Plain ZIP table collections have no descriptor authority. Settings and semantic
# mappings are kept as proposals until an exact per-member answer is approved.
plain_table_members <- function(entries)entries$Name[grepl("[.](csv|tsv|txt)$",entries$Name,ignore.case=TRUE)]

validate_archive_setting <- function(setting) {
  if(!is.list(setting)||!setequal(names(setting),c("parser","header"))||anyDuplicated(names(setting)))
    stop("Archive setting requires parser and header")
  if(!is.logical(setting$header)||length(setting$header)!=1L||is.na(setting$header))
    stop("Archive header must be TRUE or FALSE")
  list(parser=validate_parser(setting$parser),header=setting$header)
}

validate_archive_settings <- function(settings,resources,previous=NULL) {
  if(!is.list(settings))stop("archive_settings must be a named resource/member list")
  if(length(settings)&&(is.null(names(settings))||anyDuplicated(names(settings))||
    any(!names(settings)%in%resources$resource_id)))stop("Archive settings bind unknown resources")
  for(rid in names(settings)) {
    resource<-resources[resources$resource_id==rid,,drop=FALSE]
    if(tolower(tools::file_ext(resource$original_name))!="zip")stop("Member settings require a ZIP resource")
    if(!is.null(previous[[rid]])&&contract_equal(settings[[rid]],previous[[rid]])) {
      lapply(settings[[rid]],validate_archive_setting);next # Do not reopen an unchanged sibling.
    }
    entries<-utils::unzip(resource$owned_path,list=TRUE);check_archive_entries(entries)
    if(any(grepl("(^|/)meta[.]xml$",entries$Name,ignore.case=TRUE)))stop("Member overrides cannot replace an existing descriptor")
    members<-settings[[rid]]
    if(!is.list(members)||is.null(names(members))||anyDuplicated(names(members))||
      any(!names(members)%in%plain_table_members(entries)))stop("Archive settings bind unknown table members")
    lapply(members,validate_archive_setting)
  }
  invisible(settings)
}

archive_setting_approved <- function(config,rid,member,setting,source_hash) {
  any(vapply(clarification_receipts(config),function(r)isTRUE(r$approved)&&
    identical(r$type,"archive_parser")&&identical(r$resource_id,rid)&&
    identical(r$question$member,member)&&identical(r$source_sha256,source_hash)&&
    contract_equal(r$applied_value,setting),logical(1)))
}

detect_archive_bytes <- function(bytes,member,truncated=FALSE) {
  parser<-default_parser(member)
  result<-list(detector_version="parser-detection-1.0",status="needs_review",parser=parser,
    encoding=list(status="unresolved",method="none"),delimiter=list(status="unresolved",candidates=list()),
    sample_bytes=0L,sample_truncated=FALSE,message="Verify member settings and header presence.")
  detect_parser_sample(bytes,result,truncated,parser$quote)
}

# A bounded preview may end in a code point. Drop only a verified incomplete
# Unicode suffix; never discard arbitrary invalid bytes or claim full coverage.
trim_archive_preview <- function(bytes,encoding,truncated) {
  if(!truncated)return(bytes)
  for(trim in 0:3) {
    if(trim&&!is_incomplete_unicode_tail(bytes,trim,encoding))next
    candidate<-if(trim)bytes[seq_len(length(bytes)-trim)] else bytes
    decoded<-suppressWarnings(iconv(list(candidate),from=encoding,to="UTF-8",sub=NA,toRaw=TRUE)[[1]])
    if(!is.null(decoded)&&!any(decoded==as.raw(0))&&validUTF8(rawToChar(decoded)))return(candidate)
  }
  bytes # Keep genuine invalid data intact so the strict reader reports it.
}

read_plain_archive <- function(path,version_id,resource_id,limits,cancelled,
  configuration=NULL,preview_bytes=NULL) {
  entries<-utils::unzip(path,list=TRUE);check_archive_entries(entries)
  members<-plain_table_members(entries)
  ignored<-as.list(entries$Name[!entries$Name%in%members&!grepl("/$",entries$Name)])
  if(!length(members))return(list(tables=list(empty_validation_table(version_id,resource_id,
    status="unsupported",reason="ZIP contains no supported CSV/TSV/TXT table members")),
    reason="Plain ZIP has no supported tables",ignored_members=ignored))
  source_hash<-hash_file(path)
  tables<-lapply(members,function(member) {
    t<-empty_validation_table(version_id,resource_id,member)
    t$archive_mode<-"plain_zip";t$settings_pending<-TRUE
    tryCatch({
      if(cancelled())read_stop("cancelled","Reading cancelled before plain archive member")
      size<-entries$Length[entries$Name==member]
      if(size>limits$max_table_bytes)read_stop("limited","Archive member exceeds full-read byte quota")
      if(is.null(preview_bytes)) {
        bytes<-read_member(path,member,limits$max_table_bytes);prefix_truncated<-FALSE
      } else {
        con<-unz(path,member,open="rb")
        bytes<-tryCatch(readBin(con,"raw",n=preview_bytes+1L),finally=close(con))
        prefix_truncated<-length(bytes)>preview_bytes||size>preview_bytes
        bytes<-utils::head(bytes,preview_bytes)
      }
      sample<-utils::head(bytes,1024^2)
      detected<-detect_archive_bytes(sample,member,prefix_truncated||length(bytes)>length(sample))
      configured<-configuration$archive_settings[[resource_id]][[member]]
      setting<-configured
      if(is.null(setting))setting<-list(parser=detected$parser,header=TRUE)
      setting<-validate_archive_setting(setting)
      approved<-archive_setting_approved(configuration,resource_id,member,setting,source_hash)
      raw<-trim_archive_preview(bytes,setting$parser$encoding,prefix_truncated)
      if(prefix_truncated)raw<-complete_archive_preview(raw,setting$parser)
      parsed<-read_full_table(raw,version_id,resource_id,member,setting$parser,limits,cancelled,
        header=setting$header)
      # A full scan may disprove the sampled quote convention. Try literal
      # quotes only as a new proposal, never over an explicit saved setting.
      if(is.null(configured)&&parsed$status=="unreadable"&&nzchar(setting$parser$quote)&&
        grepl("Ragged table|Invalid quote|Unclosed quoted|Invalid character after closing quote",parsed$reason)) {
        alternative<-setting;alternative$parser$quote<-""
        retry<-read_full_table(raw,version_id,resource_id,member,alternative$parser,limits,cancelled,header=alternative$header)
        if(retry$status%in%c("complete","limited")&&!is.null(retry$data)) {
          detected$quote<-list(status="needs_review",proposed="",rejected_reason=parsed$reason)
          detected$status<-"needs_review"
          detected$message<-paste("Literal quotes / no enclosure is an unapproved alternative after the quoted interpretation failed.",parsed$reason)
          setting<-alternative;parsed<-retry
          approved<-archive_setting_approved(configuration,resource_id,member,setting,source_hash)
        }
      }
      parsed$archive_mode<-"plain_zip";parsed$settings_pending<-!approved
      parsed$proposed_setting<-setting;parsed$detection<-detected
      if(prefix_truncated)parsed$population_count<-NULL
      if(!approved) {
        parsed$population_count<-NULL
        parsed$reason<-paste(parsed$reason,"Member format/header proposal requires explicit approval.")
      }
      parsed
    },error=function(e) {
      t$status<-if(inherits(e,"ecodata_read_limited"))"limited" else if(inherits(e,"ecodata_read_cancelled"))"cancelled" else "unreadable"
      t$reason<-conditionMessage(e);t
    })
  })
  list(tables=tables,reason="Plain ZIP: independent table members; no descriptor declaration",
    ignored_members=ignored)
}

inspect_plain_archive <- function(path,resource_id,preview_rows,max_preview_bytes,configuration) {
  x<-read_plain_archive(path,configuration$version_id,resource_id,
    list(max_table_bytes=50*1024^2,max_rows=preview_rows,max_cells=5000000L),
    function()FALSE,configuration,preview_bytes=max_preview_bytes)
  usable<-Filter(function(t)!is.null(t$data),x$tables)
  tables<-lapply(usable,function(t)list(table_id=t$table_id,member=t$member,
    columns=names(t$data),preview=t$data,record_ids=t$record_ids,
    truncated=t$status=="limited"||is.null(t$population_count)||t$loaded_rows>=preview_rows,
    parser=t$parser,settings_pending=t$settings_pending))
  pending<-any(vapply(usable,function(t)isTRUE(t$settings_pending),logical(1)))
  failed<-length(x$tables)-length(usable)
  list(status=if(!length(usable))"unreadable" else if(pending||failed)"needs_confirmation" else "ready",
    diagnostic=paste("Plain ZIP lexical preview.",length(tables),"table(s) shown;",
      failed,"unavailable; member settings/header and semantic mappings require approval where unconfirmed.",
      paste(vapply(Filter(function(t)is.null(t$data),x$tables),function(t)t$reason,character(1)),collapse="; ")),
    tables=tables,schema_candidates=character(),ignored_members=x$ignored_members)
}

# A byte boundary is not EOF. Only terminated, quote-aware logical records can
# enter a prefix preview, so the reader cannot invent a truncated last value.
complete_archive_preview <- function(bytes,parser) {
  decoded<-suppressWarnings(iconv(list(bytes),from=parser$encoding,to="UTF-8",sub=NA,toRaw=TRUE)[[1]])
  if(is.null(decoded)||any(decoded==as.raw(0))||!validUTF8(rawToChar(decoded)))
    stop("Preview prefix does not match configured encoding")
  prefix<-complete_detection_prefix(rawToChar(decoded),parser$quote)
  if(!nzchar(prefix))stop("No complete logical records within preview byte budget")
  iconv(prefix,from="UTF-8",to=parser$encoding,sub=NA,toRaw=TRUE)[[1]]
}