#!/bin/bash
# 
# Copyright 2019 Shiyghan Navti. Email shiyghan@gmail.com
#
#################################################################################
###                   Explore DataProc on Kubernetes Engine                  ####
#################################################################################

# User prompt function
function ask_yes_or_no() {
    read -p "$1 ([y]yes to preview, [n]o to create, [d]del to delete): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        n|no)  echo "no" ;;
        d|del) echo "del" ;;
        *)     echo "yes" ;;
    esac
}

function ask_yes_or_no_proj() {
    read -p "$1 ([y]es to change, or any key to skip): "
    case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
        y|yes) echo "yes" ;;
        *)     echo "no" ;;
    esac
}

clear
MODE=1
export TRAINING_ORG_ID=$(gcloud organizations list --format 'value(ID)' --filter="displayName:techequity.training" 2>/dev/null)
export ORG_ID=$(gcloud projects get-ancestors $GCP_PROJECT --format 'value(ID)' 2>/dev/null | tail -1 )
export GCP_PROJECT=$(gcloud config list --format 'value(core.project)' 2>/dev/null)  

echo
echo
echo -e "                        👋  Welcome to Cloud Sandbox! 💻"
echo 
echo -e "              *** PLEASE WAIT WHILE LAB UTILITIES ARE INSTALLED ***"
sudo apt-get -qq install pv > /dev/null 2>&1
echo 
export SCRIPTPATH=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

function join_by { local IFS="$1"; shift; echo "$*"; }

mkdir -p `pwd`/gcp-dataproc-gke > /dev/null 2>&1
export SCRIPTNAME=gcp-dataproc-gke.sh
export PROJDIR=`pwd`/gcp-dataproc-gke

if [ -f "$PROJDIR/.env" ]; then
    source $PROJDIR/.env
else
cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=us-east1
export GCP_CLUSTER=dataproc-gke-cluster
EOF
source $PROJDIR/.env
fi

# Display menu options
while :
do
clear
cat<<EOF
==========================================================
Menu for Exploring Dataproc cluster on Kubernetes Engine 
----------------------------------------------------------
Please enter number to select your choice:
(1) Enable APIs
(2) Create network
(3) Create cluster
(4) Submit jobs
(G) Launch user guide
(Q) Quit
----------------------------------------------------------
EOF
echo "Steps performed${STEP}"
echo
echo "What additional step do you want to perform, e.g. enter 0 to select the execution mode?"
read
clear
case "${REPLY^^}" in

"0")
start=`date +%s`
source $PROJDIR/.env
echo
echo "Do you want to run script in preview mode?"
export ANSWER=$(ask_yes_or_no "Are you sure?")
cd $HOME
if [[ ! -z "$TRAINING_ORG_ID" ]]  &&  [[ $ORG_ID == "$TRAINING_ORG_ID" ]]; then
    export STEP="${STEP},0"
    MODE=1
    if [[ "yes" == $ANSWER ]]; then
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    else 
        if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
            echo 
            echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
            echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
        else
            while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                echo 
                echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                gcloud auth login  --brief --quiet
                export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                if [[ $ACCOUNT != "" ]]; then
                    echo
                    echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                    read GCP_PROJECT
                    gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                    sleep 3
                    export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                fi
            done
            gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
            sleep 2
            gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
            gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
            gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
            gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
        fi
        export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
        cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_CLUSTER=$GCP_CLUSTER
EOF
        gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
        echo
        echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
        echo "*** Google Cloud cluster is $GCP_CLUSTER ***" | pv -qL 100
        echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
        echo
        echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
        echo "*** $PROJDIR/.env ***" | pv -qL 100
        if [[ "no" == $ANSWER ]]; then
            MODE=2
            echo
            echo "*** Create mode is active ***" | pv -qL 100
        elif [[ "del" == $ANSWER ]]; then
            export STEP="${STEP},0"
            MODE=3
            echo
            echo "*** Resource delete mode is active ***" | pv -qL 100
        fi
    fi
else 
    if [[ "no" == $ANSWER ]] || [[ "del" == $ANSWER ]] ; then
        export STEP="${STEP},0"
        if [[ -f $SCRIPTPATH/.${SCRIPTNAME}.secret ]]; then
            echo
            unset password
            unset pass_var
            echo -n "Enter access code: " | pv -qL 100
            while IFS= read -p "$pass_var" -r -s -n 1 letter
            do
                if [[ $letter == $'\0' ]]
                then
                    break
                fi
                password=$password"$letter"
                pass_var="*"
            done
            while [[ -z "${password// }" ]]; do
                unset password
                unset pass_var
                echo
                echo -n "You must enter an access code to proceed: " | pv -qL 100
                while IFS= read -p "$pass_var" -r -s -n 1 letter
                do
                    if [[ $letter == $'\0' ]]
                    then
                        break
                    fi
                    password=$password"$letter"
                    pass_var="*"
                done
            done
            export PASSCODE=$(cat $SCRIPTPATH/.${SCRIPTNAME}.secret | openssl enc -aes-256-cbc -md sha512 -a -d -pbkdf2 -iter 100000 -salt -pass pass:$password 2> /dev/null)
            if [[ $PASSCODE == 'AccessVerified' ]]; then
                MODE=2
                echo && echo
                echo "*** Access code is valid ***" | pv -qL 100
                if [[ -f $PROJDIR/.${GCP_PROJECT}.json ]]; then
                    echo 
                    echo "*** Authenticating using service account key $PROJDIR/.${GCP_PROJECT}.json ***" | pv -qL 100
                    echo "*** To use a different GCP project, delete the service account key ***" | pv -qL 100
                else
                    while [[ -z "$PROJECT_ID" ]] || [[ "$GCP_PROJECT" != "$PROJECT_ID" ]]; do
                        echo 
                        echo "$ gcloud auth login --brief --quiet # to authenticate as project owner or editor" | pv -qL 100
                        gcloud auth login  --brief --quiet
                        export ACCOUNT=$(gcloud config list account --format "value(core.account)")
                        if [[ $ACCOUNT != "" ]]; then
                            echo
                            echo "Copy and paste a valid Google Cloud project ID below to confirm your choice:" | pv -qL 100
                            read GCP_PROJECT
                            gcloud config set project $GCP_PROJECT --quiet 2>/dev/null
                            sleep 3
                            export PROJECT_ID=$(gcloud projects list --filter $GCP_PROJECT --format 'value(PROJECT_ID)' 2>/dev/null)
                        fi
                    done
                    gcloud iam service-accounts delete ${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com --quiet 2>/dev/null
                    sleep 2
                    gcloud --project $GCP_PROJECT iam service-accounts create ${GCP_PROJECT} 2>/dev/null
                    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$GCP_PROJECT@$GCP_PROJECT.iam.gserviceaccount.com --role=roles/owner > /dev/null 2>&1
                    gcloud --project $GCP_PROJECT iam service-accounts keys create $PROJDIR/.${GCP_PROJECT}.json --iam-account=${GCP_PROJECT}@${GCP_PROJECT}.iam.gserviceaccount.com 2>/dev/null
                    gcloud --project $GCP_PROJECT storage buckets create gs://$GCP_PROJECT > /dev/null 2>&1
                fi
                export GOOGLE_APPLICATION_CREDENTIALS=$PROJDIR/.${GCP_PROJECT}.json
                cat <<EOF > $PROJDIR/.env
export GCP_PROJECT=$GCP_PROJECT
export GCP_REGION=$GCP_REGION
export GCP_CLUSTER=$GCP_CLUSTER
EOF
                gsutil cp $PROJDIR/.env gs://${GCP_PROJECT}/${SCRIPTNAME}.env > /dev/null 2>&1
                echo
                echo "*** Google Cloud project is $GCP_PROJECT ***" | pv -qL 100
                echo "*** Google Cloud cluster is $GCP_CLUSTER ***" | pv -qL 100
                echo "*** Google Cloud region is $GCP_REGION ***" | pv -qL 100
                echo
                echo "*** Update environment variables by modifying values in the file: ***" | pv -qL 100
                echo "*** $PROJDIR/.env ***" | pv -qL 100
                if [[ "no" == $ANSWER ]]; then
                    MODE=2
                    echo
                    echo "*** Create mode is active ***" | pv -qL 100
                elif [[ "del" == $ANSWER ]]; then
                    export STEP="${STEP},0"
                    MODE=3
                    echo
                    echo "*** Resource delete mode is active ***" | pv -qL 100
                fi
            else
                echo && echo
                echo "*** Access code is invalid ***" | pv -qL 100
                echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
                echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
                echo
                echo "*** Command preview mode is active ***" | pv -qL 100
            fi
        else
            echo
            echo "*** You can use this script in our Google Cloud Sandbox without an access code ***" | pv -qL 100
            echo "*** Contact support@techequity.cloud for assistance ***" | pv -qL 100
            echo
            echo "*** Command preview mode is active ***" | pv -qL 100
        fi
    else
        export STEP="${STEP},0i"
        MODE=1
        echo
        echo "*** Command preview mode is active ***" | pv -qL 100
    fi
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"1")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},1i"
    echo
    echo "$ gcloud services enable --project=\$GCP_PROJECT dataproc.googleapis.com # to enable APIs" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},1"
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "$ gcloud services enable --project=$GCP_PROJECT dataproc.googleapis.com # to enable APIs" | pv -qL 100
    gcloud services enable --project=$GCP_PROJECT dataproc.googleapis.com
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},1x"
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},1i"
    echo
    echo "1. Enable APIs" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"2")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},2i"   
    echo
    echo "$ gcloud --project \$GCP_PROJECT compute networks create dataproc-net --subnet-mode custom # to create custom network" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT compute networks subnets create dataproc-subnet --network dataproc-net --region \$GCP_REGION --range 10.128.0.0/20 --enable-private-ip-google-access # to create subnet" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},2"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1 
    echo
    echo "$ gcloud --project $GCP_PROJECT compute networks create dataproc-net --subnet-mode custom # to create custom network" | pv -qL 100
    gcloud --project $GCP_PROJECT compute networks create dataproc-net --subnet-mode custom
    echo
    echo "$ gcloud --project $GCP_PROJECT compute networks subnets create dataproc-subnet --network dataproc-net --region $GCP_REGION --range 10.128.0.0/20 --enable-private-ip-google-access # to create subnet" | pv -qL 100
    gcloud --project $GCP_PROJECT compute networks subnets create dataproc-subnet --network dataproc-net --region $GCP_REGION --range 10.128.0.0/20 --enable-private-ip-google-access
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},2x"   
    echo
    echo "$ gcloud --project $GCP_PROJECT compute networks subnets delete dataproc-subnet --region $GCP_REGION # to delete subnet" | pv -qL 100
    gcloud --project $GCP_PROJECT compute networks subnets delete dataproc-subnet --region $GCP_REGION
    echo
    echo "$ gcloud --project $GCP_PROJECT compute networks delete dataproc-net # to create custom network" | pv -qL 100
    gcloud --project $GCP_PROJECT compute networks delete dataproc-net
else
    export STEP="${STEP},2i"
    echo
    echo "1. Create network" | pv -qL 100
    echo "2. Configure subnet" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"3")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},3i"
    echo
    echo "$ gcloud projects add-iam-policy-binding \$GCP_PROJECT --member serviceAccount:\$PROJECT_NUMBER-compute@developer.gserviceaccount.com --role roles/storage.objectAdmin --role=roles/bigquery.dataEditor # to allow workloads to access buckets and data sets" | pv -qL 100
    echo
    echo "$ gcloud --project \$GCP_PROJECT beta container clusters create \$GCP_CLUSTER --region \$GCP_REGION--machine-type=e2-standard-4 --num-nodes=1 --workload-pool=\$WORKLOAD_POOL --network dataproc-net --subnetwork dataproc-subnet --labels=mesh_id=\$MESH_ID,location=\$GCP_REGION --node-locations=\${GCP_REGION}-b,\${GCP_REGION}-c --spot # to create container cluster" | pv -qL 100
    echo      
    echo "$ gcloud --project \$GCP_PROJECT container clusters get-credentials \$GCP_CLUSTER --region \$GCP_REGION # to retrieve the credentials for cluster" | pv -qL 100
    echo
    echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"\$(gcloud config get-value core/account)\" # to enable current user to set RBAC rules" | pv -qL 100
    echo
    echo "$ gcloud dataproc clusters gke create dataproc-gke-cluster --region \$GCP_REGION --gke-cluster=\$GCP_CLUSTER --spark-engine-version=latest --staging-bucket=\$GCP_PROJECT --pools=\"name=dataproc-pool,roles=default,machineType=e2-standard-4,min=0,max=2\" --setup-workload-identity # to create dataproc cluster" | pv -qL 100
    echo
    echo "$ gcloud dataproc clusters export dataproc-gke-cluster --region \$GCP_REGION > \$PROJDIR/\${GCP_CLUSTER}-config.yaml # to export configuration" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},3"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    export PROJECT_NUMBER=$(gcloud projects describe $GCP_PROJECT --format="value(projectNumber)")
    export MESH_ID="proj-${PROJECT_NUMBER}" # sets the mesh_id label on the cluster
    export WORKLOAD_POOL=${GCP_PROJECT}.svc.id.goog
    echo
    echo "$ gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com --role roles/storage.objectAdmin --role=roles/bigquery.dataEditor # to allow workloads to access buckets and data sets" | pv -qL 100
    gcloud projects add-iam-policy-binding $GCP_PROJECT --member serviceAccount:$PROJECT_NUMBER-compute@developer.gserviceaccount.com --role "roles/storage.objectAdmin" --role "roles/bigquery.dataEditor"
    echo
    echo "$ gcloud --project $GCP_PROJECT beta container clusters create $GCP_CLUSTER --region $GCP_REGION--machine-type=e2-standard-4 --num-nodes=1 --workload-pool=${WORKLOAD_POOL} --network dataproc-net --subnetwork dataproc-subnet --labels=mesh_id=${MESH_ID},location=$GCP_REGION --node-locations=${GCP_REGION}-b,${GCP_REGION}-c --spot # to create container cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT beta container clusters create $GCP_CLUSTER --region $GCP_REGION --machine-type=e2-standard-4 --num-nodes=1 --workload-pool=${WORKLOAD_POOL} --network dataproc-net --subnetwork dataproc-subnet --labels=mesh_id=${MESH_ID},location=$GCP_REGION --node-locations=${GCP_REGION}-b,${GCP_REGION}-c --spot
    echo      
    echo "$ gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION # to retrieve the credentials for cluster" | pv -qL 100
    gcloud --project $GCP_PROJECT container clusters get-credentials $GCP_CLUSTER --region $GCP_REGION
    echo
    echo "$ kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user=\"\$(gcloud config get-value core/account)\" # to enable current user to set RBAC rules" | pv -qL 100
    kubectl create clusterrolebinding cluster-admin-binding --clusterrole=cluster-admin --user="$(gcloud config get-value core/account)"
    echo
    echo "$ gcloud dataproc clusters gke create dataproc-gke-cluster --region $GCP_REGION --gke-cluster=$GCP_CLUSTER --spark-engine-version=latest --staging-bucket=$GCP_PROJECT --pools=\"name=dataproc-pool,roles=default,machineType=e2-standard-4,min=0,max=2\" --setup-workload-identity # to create dataproc cluster" | pv -qL 100
    gcloud dataproc clusters gke create dataproc-gke-cluster --region $GCP_REGION --gke-cluster=$GCP_CLUSTER --spark-engine-version=latest --staging-bucket=$GCP_PROJECT --pools="name=dataproc-pool,roles=default,machineType=e2-standard-4,min=0,max=2" --setup-workload-identity
    echo
    echo "$ gcloud dataproc clusters export dataproc-gke-cluster --region $GCP_REGION > $PROJDIR/${GCP_CLUSTER}-config.yaml # to export configuration" | pv -qL 100
    gcloud dataproc clusters export dataproc-gke-cluster --region $GCP_REGION > $PROJDIR/${GCP_CLUSTER}-config.yaml
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},3x"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    echo
    echo "$ gcloud dataproc clusters delete dataproc-gke-cluster --region $GCP_REGION # to delete cluster" | pv -qL 100
    gcloud dataproc clusters delete dataproc-gke-cluster --region $GCP_REGION
    echo
    echo "$ gcloud beta container clusters delete $GCP_CLUSTER --region $GCP_REGION # to delete cluster" | pv -qL 100
    gcloud beta container clusters delete $GCP_CLUSTER --region $GCP_REGION 
else
    export STEP="${STEP},3i"   
    echo
    echo "1. Create dataproc cluster" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"4")
start=`date +%s`
source $PROJDIR/.env
if [ $MODE -eq 1 ]; then
    export STEP="${STEP},4i"
    echo
    echo "$ gcloud dataproc jobs submit spark --cluster dataproc-gke-cluster --region=\$GCP_REGION --class org.apache.spark.examples.SparkPi --jars file:///usr/lib/spark/examples/jars/spark-examples.jar -- 1000 # to submit SparkPi job" | pv -qL 100
    echo
    echo "$ gcloud dataproc jobs submit pyspark gs://dataproc-examples/pyspark/hello-world/hello-world.py --cluster dataproc-gke-cluster --region \$GCP_REGION # to submit PySpark job" | pv -qL 100
    echo
    echo "$ gcloud dataproc jobs submit pyspark --region \$GCP_REGION --cluster dataproc-gke-cluster file:///usr/lib/spark/examples/src/main/python/pi.py -- 10 # to submit PySpark job" | pv -qL 100
elif [ $MODE -eq 2 ]; then
    export STEP="${STEP},4"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    echo
    echo "$ gcloud dataproc jobs submit spark --cluster dataproc-gke-cluster --region=$GCP_REGION --class org.apache.spark.examples.SparkPi --jars file:///usr/lib/spark/examples/jars/spark-examples.jar -- 1000 # to submit SparkPi job" | pv -qL 100
    gcloud dataproc jobs submit spark --cluster dataproc-gke-cluster --region=$GCP_REGION --class org.apache.spark.examples.SparkPi --jars file:///usr/lib/spark/examples/jars/spark-examples.jar -- 1000
    echo
    echo "$ gcloud dataproc jobs submit pyspark gs://dataproc-examples/pyspark/hello-world/hello-world.py --cluster dataproc-gke-cluster --region $GCP_REGION # to submit PySpark job" | pv -qL 100
    gcloud dataproc jobs submit pyspark gs://dataproc-examples/pyspark/hello-world/hello-world.py --cluster dataproc-gke-cluster --region $GCP_REGION
    echo
    echo "$ gcloud dataproc jobs submit pyspark --region $GCP_REGION --cluster dataproc-gke-cluster file:///usr/lib/spark/examples/src/main/python/pi.py -- 10 # to submit PySpark job" | pv -qL 100
    gcloud dataproc jobs submit pyspark --region $GCP_REGION --cluster dataproc-gke-cluster file:///usr/lib/spark/examples/src/main/python/pi.py -- 10
elif [ $MODE -eq 3 ]; then
    export STEP="${STEP},4x"   
    gcloud config set project $GCP_PROJECT > /dev/null 2>&1
    echo
    echo "*** Nothing to delete ***" | pv -qL 100
else
    export STEP="${STEP},4i"   
    echo
    echo "1. Submit jobs to dataproc cluster" | pv -qL 100
fi
end=`date +%s`
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;
 
"R")
echo
echo "
  __                      __                              __                               
 /|            /         /              / /              /                 | /             
( |  ___  ___ (___      (___  ___        (___           (___  ___  ___  ___|(___  ___      
  | |___)|    |   )     |    |   )|   )| |    \   )         )|   )|   )|   )|   )|   )(_/_ 
  | |__  |__  |  /      |__  |__/||__/ | |__   \_/       __/ |__/||  / |__/ |__/ |__/  / / 
                                 |              /                                          
"
echo "
We are a group of information technology professionals committed to driving cloud 
adoption. We create cloud skills development assets during our client consulting 
engagements, and use these assets to build cloud skills independently or in partnership 
with training organizations.
 
You can access more resources from our iOS and Android mobile applications.

iOS App: https://apps.apple.com/us/app/tech-equity/id1627029775
Android App: https://play.google.com/store/apps/details?id=com.techequity.app

Email:support@techequity.cloud 
Web: https://techequity.cloud

Ⓒ Tech Equity 2022" | pv -qL 100
echo
echo Execution time was `expr $end - $start` seconds.
echo
read -n 1 -s -r -p "$ "
;;

"G")
cloudshell launch-tutorial $SCRIPTPATH/.tutorial.md
;;

"Q")
echo
exit
;;
"q")
echo
exit
;;
* )
echo
echo "Option not available"
;;
esac
sleep 1
done

"Q")
echo
exit
;;
"q")
echo
exit
;;
* )
echo
echo "Option not available"
;;
esac
sleep 1
done
