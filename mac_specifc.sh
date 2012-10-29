##############################
# Aliases
##############################
alias ls="gls -ltrhF --color"
alias l="gls -lAh --color"
alias ll="gls -l --color"
alias la='gls -A --color'


##############################
# Ad Tools Specific to Intent Media
##############################
function jstest() {
    ant -Dargs="$1" -f $INTENT_HOME/tags/build/build.xml start-and-run-all
}

function spoof_ads() {
    sudo $INTENT_HOME/conf/scripts/spoof_ads/spoof_ads $@
}

function spoof_ads_alpha() {
    sudo $INTENT_HOME/conf/scripts/spoof_ads/spoof_ads_alpha $@
}

function respoof() {
    ant -f $INTENT_HOME/adServer/build/build.xml concatenate && spoof_ads on
}



#####################################
# Database Migrations Specif to Intent Media
#####################################
function dbMigrateAndPrepAll() {
  dbMigrateBase
  dbTestPrepareBase
  dbMigrateExtranet
  dbTestPrepareExtranet
}

function dbMigrateAndPrepXnet() {
  dbMigrateExtranet
  dbTestPrepareExtranet
}

function dbMigrateBase() {
  currentDir=`pwd`
  cd $CODE/dataMigrations
  echo "Migrating base"
  bundle exec rake db:migrate
  cd $currentDir
}

function dbTestPrepareBase() {
  currentDir=`pwd`
  cd $CODE/dataMigrations
  echo "Preparing base"
  bundle exec rake db:test:prepare
  cd $currentDir
}

function dbMigrateExtranet() {
  currentDir=`pwd`
  cd $EXTRANET/db
  echo "Migrating extranet"
  bundle exec rake db:migrate
  cd $currentDir
}

function dbTestPrepareExtranet() {
  currentDir=`pwd`
  cd $EXTRANET/db
  echo "Preparing extranet"
  bundle exec rake db:test:prepare
  cd $currentDir
}

##################
# Convert ERB to HAML
##################
function haml_move() {
  [[ $1 =~ (.+)\.erb ]]
  erb_name="${BASH_REMATCH[1]}"
  git mv "${erb_name}.erb" "${erb_name}.haml" &&  git add "${erb_name}.haml"
}

function haml_convert() {
  cat "$1" | bundle exec html2haml -s -e "$1" && git add "$1"
}