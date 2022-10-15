#!/bin/bash
#

function is_in_local() {
    local branch=${1}
    local existed_in_local=$(git branch --list ${branch})

    if [[ -z ${existed_in_local} ]]; then
        echo 0
    else
        echo 1
    fi
}

function is_in_remote() {
    local branch=${1}
    local existed_in_remote=$(git ls-remote --heads origin ${branch})

    if [[ -z ${existed_in_remote} ]]; then
        echo 0
    else
        echo 1
    fi
}

currentbranch=`git branch --show-current`
echo "current branch = $currentbranch"

if [[ ${currentbranch} == "main" ]]; then
  # in main configure site
  read -p "Site Name: " sitename
  if [ ! "${sitename}" ]; then echo "Error: no sitename provided" ;exit; fi
  if [[ `is_in_local ${sitename}` == 1 ]]; then
    git switch ${sitename} && jq -r ".sitename = \"${sitename}\" " manifests/site.json | sponge manifests/site.json && git add manifests/site.json && git commit -m "configuring site manifest"
  else
    git checkout -b ${sitename} && jq -r ".sitename = \"${sitename}\" " manifests/site.json | sponge manifests/site.json && git add manifests/site.json && git commit -m "configuring site manifest"
  fi
  currentbranch=`git branch --show-current`
else
  # reconfiguring a site
  currentbranch=`git branch --show-current`
  read -p "Site Name: [${currentbranch}] " sitename
  sitename="${sitename:=${currentbranch}}"
  if [[ ${currentbranch} != ${sitename} ]]; then
    if [[ `is_in_local ${sitename}` == 1 ]]; then
      git switch ${sitename} && jq -r ".sitename = \"${sitename}\" " manifests/site.json | sponge manifests/site.json && git add manifests/site.json && git commit -m "configuring site manifest"
    else
      git checkout -b ${sitename} && jq -r ".sitename = \"${sitename}\" " manifests/site.json | sponge manifests/site.json && git add manifests/site.json && git commit -m "configuring site manifest"
    fi
    currentbranch=`git branch --show-current`
  fi
fi

sitename=$currentbranch

timeout () {
    tput sc
    time=$1; while [ $time -ge 0 ]; do
        tput rc; tput el
        printf "$2" $time
        ((time--))
        sleep 1
    done
    tput rc; tput ed;
}

cd manifests/
address=`jq -r ".address" site.json`

read -p "Site Address: [${address}] " address
address="${address:=${address}}"

currentlatitude=`jq -r ".latitude" site.json`
read -p "Site Latitude: [${currentlatitude}] " latitude
latitude="${latitude:=${currentlatitude}}"

currentlongitude=`jq -r ".longitude" site.json`
read -p "Site Longitude: [${currentlongitude}] " longitude
longitude="${longitude:=${currentlongitude}}"

currentcenodename=`jq -r ".cenodename" site.json`
read -p "CE Node hostname: [${currentcenodename}] " cenodename
cenodename="${cenodename:=${currentcenodename}}"

currentcenodeaddress=`jq -r ".cenodeaddress" site.json`
read -p "CE Node IP Addr or DNS name: [${currentcenodeaddress}] " cenodeaddress
cenodeaddress="${cenodeaddress:=${currentcenodeaddress}}"

currentcenodeport=`jq -r ".cenodeport" site.json`
read -p "CE Node Port: [${currentcenodeport}] " cenodeport
cenodeport="${cenodeport:=${currentcenodeport}}"

echo "# Create manifests"

echo "# Create K8s clsuter"
jq -r ".address = \"${address}\" | .latitude = \"${latitude}\" | .longitude = \"${longitude}\" | .cenodeaddress = \"${cenodeaddress}\" | .cenodeport = \"${cenodeport}\" | .cenodename = \"${cenodename}\" " site.json | sponge site.json
git add site.json && git commit --quiet -m "creating deployment manifests"

echo "# Create K8s clsuter"
jq -r ".metadata.name = \"${sitename}\" | .spec.cluster_wide_app_list.cluster_wide_apps[].argo_cd.local_domain.password.blindfold_secret_info.location = \"<removed>\" " k8s_cluster.json | sponge k8s_cluster.json
git add k8s_cluster.json && git commit --quiet -m "creating deployment manifests"

echo "# Create an appstack site"
jq -r ".metadata.name = \"${sitename}\" | .spec.k8s_cluster.name = \"${sitename}\" | .spec.master_nodes[] = \"${nodename}\" | .spec.address = \"${address}\" | .spec.coordinates.latitude = \"${latitude}\" | .spec.coordinates.longitude = \"${longitude}\" " appstack_site.json | sponge appstack_site.json
git add appstack_site.json && git commit --quiet -m "creating deployment manifests"

echo "# Create a site registration approval"
jq -r ".metadata.name = \"${sitename}-token\" " token.json | sponge token.json
git add token.json && git commit --quiet -m "creating deployment manifests"

echo "# Create CE registraion"
jq -r ".cluster_name = \"${sitename}\" | .hostname = \"${nodename}\" | .latitude = \"${latitude}\" | .longitude = \"${longitude}\" " ce-register.json | sponge ce-register.json
git add ce-register.json && git commit --quiet -m "creating deployment manifests"

echo "# Update documentation"


