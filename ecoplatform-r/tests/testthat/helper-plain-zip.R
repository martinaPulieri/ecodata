plain_zip_fixture <- function(files=list(
  "Occurrence.tsv"="id\teventDate\n001\t03/04/2020\n002\t2021\n",
  "MeasurementOrFact.tsv"="id\tmeasurementDeterminedDate\n001\t2020\n002\t2021\n",
  "query.json"='{"note":"sidecar only"}',"citations.html"="<html>not executed</html>")) {
  stage<-tempfile("plain-zip-");dir.create(stage)
  for(member in names(files)) {
    target<-file.path(stage,member);dir.create(dirname(target),recursive=TRUE,showWarnings=FALSE)
    bytes<-files[[member]];if(is.character(bytes))bytes<-charToRaw(bytes)
    writeBin(bytes,target)
  }
  path<-tempfile(fileext=".zip");zip::zipr(path,names(files),root=stage,mode="mirror")
  path
}

approve_zip_settings <- function(repo,version_id,config_id,member,setting=NULL) {
  q<-prepare_clarifications(repo,version_id,config_id)
  item<-Filter(function(q)q$type=="archive_parser"&&identical(q$member,member),q$questions)[[1]]
  if(is.null(setting))setting<-item$suggestions[[1]]$answer
  draft<-preview_clarification_answer(repo,q,item$question_id,setting,
    "Synthetic owner confirms encoding, separator and header","synthetic-owner")
  approve_clarification_answer(repo,draft,TRUE)
}
