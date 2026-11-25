# Parse descriptor facts, not header aliases. Every table keeps its declaration
# even when its data member cannot be read, so prerequisites can fail independently.
descriptor_index <- function(nodes) {
  if(length(nodes)!=1L)return(list(position=NULL,state=if(length(nodes))"ambiguous" else "missing",reason="Missing or ambiguous declared index"))
  text<-xml2::xml_attr(nodes,"index")
  if(is.na(text)||!grepl("^(0|[1-9][0-9]*)$",text))return(list(position=NULL,state="invalid",reason="Invalid declared index"))
  number<-as.numeric(text)
  if(!is.finite(number)||number>.Machine$integer.max)return(list(position=NULL,state="invalid",reason="Declared index exceeds supported range"))
  list(position=number,state="declared",reason="")
}

read_validation_archive <- function(path,version_id,resource_id,limits,cancelled,configuration=NULL) {
  entries<-utils::unzip(path,list=TRUE);check_archive_entries(entries)
  metas<-entries$Name[grepl("(^|/)meta\\.xml$",entries$Name,ignore.case=TRUE)]
  if(!length(metas))return(read_plain_archive(path,version_id,resource_id,limits,cancelled,configuration))
  if(length(metas)!=1L)stop("ZIP requires one supported meta.xml descriptor")
  if(entries$Length[entries$Name==metas]>1024^2)read_stop("limited","Descriptor exceeds the separate 1 MiB metadata quota")
  bytes<-read_member(path,metas,1024^2)
  if(grepl("<!DOCTYPE|<!ENTITY",rawToChar(bytes),ignore.case=TRUE))stop("DTD/entity declarations are not supported")
  doc<-xml2::read_xml(bytes,options="NONET")
  root<-xml2::xml_find_first(doc,"/*[local-name()='archive']")
  if(inherits(root,"xml_missing"))stop("Invalid archive descriptor")
  if(length(xml2::xml_find_all(root,"descendant-or-self::*[namespace-uri() != 'http://rs.tdwg.org/dwc/text/']")))stop("Unsupported descriptor element namespace")
  nodes<-xml2::xml_find_all(root,"./*[local-name()='core' or local-name()='extension']")
  if(!length(nodes))stop("Descriptor has no core or extension tables")
  attr_or<-function(node,key,default){x<-xml2::xml_attr(node,key);if(is.na(x))default else x}
  declarations<-list()
  for(n in seq_along(nodes)) {
    node<-nodes[[n]];kind<-xml2::xml_name(node)
    locations<-xml2::xml_text(xml2::xml_find_all(node,"./*[local-name()='files']/*[local-name()='location']"))
    location_issue<-if(!length(locations))"Descriptor table has no file location" else ""
    if(!length(locations))locations<-paste0("__missing_location_",n)
    fields<-xml2::xml_find_all(node,"./*[local-name()='field']")
    field_specs<-lapply(seq_along(fields),function(i)c(list(term=attr_or(fields[[i]],"term","")),descriptor_index(fields[i])))
    key<-descriptor_index(xml2::xml_find_all(node,if(kind=="core")"./*[local-name()='id']" else "./*[local-name()='coreid']"))
    for(location in locations) {
      check_archive_entries(data.frame(Name=location,Length=0))
      member<-if(dirname(metas)==".")location else paste(dirname(metas),location,sep="/")
      declarations[[length(declarations)+1L]]<-list(node=node,member=member,kind=kind,
        row_type=attr_or(node,"rowType",""),key=key,fields=field_specs,descriptor_member=metas,
        node_number=n,location_issue=location_issue,descriptor_sha256=digest::digest(bytes,algo="sha256",serialize=FALSE))
    }
  }
  members<-vapply(declarations,function(d)tolower(d$member),character(1))
  # Reject identity collisions before decompressing a member twice.
  if(anyDuplicated(members))stop("Descriptor has duplicate member references")
  tables<-lapply(declarations,function(declaration) {
    node<-declaration$node;declaration$node<-NULL
    failed<-function(reason,status="unreadable")empty_validation_table(version_id,resource_id,declaration$member,status,reason,declaration)
    tryCatch({
      if(cancelled())read_stop("cancelled","Reading cancelled before archive member")
      if(nzchar(declaration$location_issue))stop(declaration$location_issue)
      if(!declaration$member%in%entries$Name)stop("Declared archive member is missing")
      size<-entries$Length[entries$Name==declaration$member]
      if(size>limits$max_table_bytes)read_stop("limited","Archive member exceeds full-read byte quota")
      delimiter<-attr_or(node,"fieldsTerminatedBy",",");if(identical(delimiter,"\\t"))delimiter<-"\t"
      parser<-validate_parser(list(delimiter=delimiter,encoding=attr_or(node,"encoding","UTF-8"),
        decimal_mark=".",quote=attr_or(node,"fieldsEnclosedBy",'"')))
      ignore<-attr_or(node,"ignoreHeaderLines","0")
      if(!ignore%in%c("0","1"))stop("Only zero or one declared header line is supported")
      line<-xml2::xml_attr(node,"linesTerminatedBy")
      separator<-if(is.na(line))NULL else switch(line,"\\n"="\n","\\r"="\r","\\r\\n"="\r\n",line)
      if(!is.null(separator)&&!separator%in%c("\n","\r","\r\n"))stop("Unsupported linesTerminatedBy")
      raw<-read_member(path,declaration$member,limits$max_table_bytes)
      read_full_table(raw,version_id,resource_id,declaration$member,parser,limits,cancelled,
        header=ignore=="1",record_separator=separator,declaration=declaration)
    },error=function(e)failed(conditionMessage(e),if(inherits(e,"ecodata_read_limited"))"limited" else if(inherits(e,"ecodata_read_cancelled"))"cancelled" else "unreadable"))
  })
  list(tables=tables,reason="Descriptor parsed; each member assessed independently")
}
