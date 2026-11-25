linkage_engine_fixture <- function(repo,core="id,occurrenceID,Date observed\n001,obs-a,2020\nDUP,obs-b,2020\nDUP,obs-c,2020\n,obs-d,2020\nNA,obs-e,2020\n space,obs-f,2020\nunused,obs-g,2020\n",
 extension="coreid,value\n001,1\n001,2\nDUP,3\n,4\nmissing,5\nNA,6\n001 ,7\n space,8\n1,9\n") {
  full_fixture(repo,full_archive(core=core,extension=extension))
}
