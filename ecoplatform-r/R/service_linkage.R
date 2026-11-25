#' Evaluate exact archive linkage without modifying data or saving results
#'
#' Reads exact registered/configured tables, checks independent prerequisites,
#' and runs LNK-02--06 with enabled LNK-07/08 diagnostics. One outcome is returned
#' per known eligible measurement row. Ready prerequisites alone are not findings.
#' @param repo Open repository handle.
#' @param version_id Exact active immutable source version.
#' @param config_id Exact configuration belonging to that version.
#' @param mapping_id Optional exact saved or descriptor-derived mapping ID.
#' @param cancelled Cooperative function returning exactly one nonmissing logical.
#' @param max_output_rows Maximum combined core/extension source rows represented
#'   per run (default 25000), bounding row results and multiplicity details.
#' @param max_candidate_targets Maximum total candidate row locators per run.
#' @param max_findings Maximum findings per run. Exceeding a quota discards
#'   scientific output and reports a limited, unevaluated mapping.
#' @param expected_workspace_revision Optional displayed lifecycle revision.
#' @return linkage-evaluation-1.0 with scoped effective frozen contexts, original
#'   config/source hashes, typed rows/findings/checks, reconciled summaries and
#'   date prerequisites. No configurations, operations or result rows are saved.
#' @export
run_linkage_validation <- function(repo,version_id,config_id,mapping_id=NULL,
  cancelled=function()FALSE,max_output_rows=25000L,max_candidate_targets=250000L,
  max_findings=100000L,expected_workspace_revision=NULL) {
  if(!is.function(cancelled))stop("cancelled must be a function")
  cancel<-function(){
    flag<-cancelled()
    if(!is.logical(flag)||length(flag)!=1L||is.na(flag))stop("Invalid cancellation flag")
    flag
  }
  limits<-list(max_output_rows=integer_bound(max_output_rows,"max_output_rows",1000000L),
    max_candidate_targets=integer_bound(max_candidate_targets,"max_candidate_targets",10000000L),
    max_findings=integer_bound(max_findings,"max_findings",1000000L))
  input<-read_validation_tables(repo,version_id,config_id,cancelled=cancel,
    expected_workspace_revision=expected_workspace_revision)
  output<-evaluate_linkage_preparation(input,mapping_id,cancel,limits)
  # Invalidate only affected resources if bytes change during evaluation.
  after<-verify_input(repo,version_id)$resources
  bad<-union(after$resource_id[is.na(after$ok)|!after$ok],
    setdiff(vapply(input$resources,function(r)r$resource_id,character(1)),after$resource_id))
  if(length(bad)) {
    for(i in seq_along(input$tables))if(input$tables[[i]]$resource_id%in%bad) {
      t<-input$tables[[i]]
      input$tables[[i]]<-empty_validation_table(input$version_id,t$resource_id,t$member,
        reason="Source integrity changed during linkage evaluation",declaration=t$declaration)
    }
    invalidate<-function(p) {
      if(p$resource_id%in%bad) {
        p$status<-"not_evaluated";p$reason<-"Source integrity changed during linkage evaluation"
        p["population_count"]<-list(NULL);p$eligible_rows<-0L;p$scientific_rows_evaluated<-0L
      }
      p
    }
    output$prerequisites<-lapply(output$prerequisites,invalidate)
    output$date_prerequisites<-lapply(output$date_prerequisites,invalidate)
    for(i in seq_along(output$mappings)) {
      m<-output$mappings[[i]]
      if(m$resource_id%in%bad)output$mappings[[i]]<-linkage_blocked(input,
        output$prerequisites[[i]],"unreadable","Source integrity changed during linkage evaluation",limits,m$context)
    }
  }
  assert_workspace_active(repo,version_id,input$workspace_revision)
  if(cancel())for(i in seq_along(output$mappings))output$mappings[[i]]<-linkage_blocked(input,
    output$prerequisites[[i]],"cancelled","Run cancelled before return; partial records discarded",limits,output$mappings[[i]]$context)
  output<-finish_linkage_evaluation(output)
  output
}

# Internal entry permits unit/manual checks to reuse a freshly read preparation.
# Callers must use the public service when they need repository/lifecycle guards.
evaluate_linkage_preparation <- function(input,mapping_id=NULL,cancelled=function()FALSE,
  limits=list(max_output_rows=25000L,max_candidate_targets=250000L,max_findings=100000L)) {
  if(!identical(input$contract_version,"validation-preparation-1.0"))stop("Unsupported validation preparation")
  prerequisites<-assess_validation_prerequisites(input)
  selected<-complete_saved_linkage_prerequisites(input,prerequisites$linkage)
  if(!is.null(mapping_id)) {
    scalar_text(mapping_id,"mapping_id")
    selected<-Filter(function(p)!is.null(p$mapping)&&identical(p$mapping$mapping_id,mapping_id),selected)
    if(length(selected)!=1L)stop("Unknown or ambiguous linkage mapping_id")
  }
  remaining<-limits
  mappings<-vector("list",length(selected))
  for(i in seq_along(selected)) {
    result<-evaluate_linkage_mapping(input,selected[[i]],remaining,cancelled)
    used_rows<-if(result$status=="completed")result$core_population+result$extension_population else length(result$rows)
    remaining$max_output_rows<-max(0,remaining$max_output_rows-used_rows)
    remaining$max_findings<-max(0,remaining$max_findings-length(result$findings))
    targets<-sum(vapply(result$rows,function(row)length(row$candidate_core_locators),numeric(1)))
    remaining$max_candidate_targets<-max(0,remaining$max_candidate_targets-targets)
    mappings[[i]]<-result
  }
  finish_linkage_evaluation(list(contract_version="linkage-evaluation-1.0",
    engine_version="exact-linkage-1.0",version_id=input$version_id,config_id=input$config_id,
    config_hash=input$config_hash,rules_source=if(is.null(input$configuration$validation_spec))"application_defaults" else "configuration",
    prerequisites=selected,date_prerequisites=prerequisites$dates,limits=limits,mappings=mappings))
}

finish_linkage_evaluation <- function(output) {
  states<-vapply(output$mappings,function(m)m$status,character(1))
  output$status<-if(any(states=="cancelled"))"cancelled" else
    if(length(states)&&all(states=="completed"))"completed" else
      if(length(states)&&all(states=="not_applicable"))"not_applicable" else "completed_with_limitations"
  output$contexts<-Filter(Negate(is.null),lapply(output$mappings,function(m)m$context))
  output$context<-if(length(output$contexts)==1L)output$contexts[[1]] else NULL
  output$result_hash<-NULL
  output$result_hash<-hash_text(json_text(output))
  output
}


# Every saved mapping must be represented even if descriptor preparation cannot
# resolve its member. Never silently replace a saved declaration by a default.
complete_saved_linkage_prerequisites <- function(input,prerequisites) {
  for(mapping in input$configuration$validation_spec$linkage_mappings) {
    exact<-vapply(prerequisites,function(p)!is.null(p$mapping)&&contract_equal(p$mapping,mapping),logical(1))
    if(any(exact))next
    for(i in seq_along(prerequisites)) {
      p<-prerequisites[[i]]
      if(!is.null(p$mapping)&&identical(p$mapping$mapping_id,mapping$mapping_id)) {
        prerequisites[[i]]$status<-"not_evaluated"
        prerequisites[[i]]$eligible_rows<-0L
        prerequisites[[i]]$reason<-"Descriptor-derived mapping ID conflicts with a different saved mapping"
      }
    }
    related<-Filter(function(p)identical(p$table_id,mapping$extension$table$table_id),prerequisites)
    reason<-if(length(related))paste("Saved mapping unavailable:",paste(unique(vapply(related,function(p)p$reason,character(1))),collapse="; ")) else
      "Saved relationship member/declaration is absent from usable linkage prerequisites"
    prerequisites[[length(prerequisites)+1L]]<-prerequisite_record("LNK-01","linkage",
      "not_evaluated",reason,find_prepared_table(input,mapping$extension$table$table_id),mapping)
  }
  prerequisites
}