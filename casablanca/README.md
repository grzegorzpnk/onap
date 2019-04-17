This is a guide how to install ONAP using ONAP Operations Manager (OOM).

When you have up and running ONAP UnderCloud (see heat/ directory) you can proceed to ONAP installation.

Login to Rancher VM. You should have *kubectl* configured. Check it by using:

`kubectl get pods --all-namespaces`

#If you have some problems here, make sure that file ~/.kube/config exists. If not, log into Rancher dashboard, next click kubernetes and CLI and generate kubernetes config file. Next copy paste this config into above localization. If file do not exist at all, create it.#

In order to install ONAP, Firstly you need to download this repository. In this repo you can find ONAP config files, that you should use instead of original repo of ONAP.

`git clone http://10.254.188.33/onap/integration-advnet.git -b casablanca`

`cd integration-advnet/casablanca/`

Download official OOM repository.

`git clone -b casablanca http://gerrit.onap.org/r/oom`

Override ONAP configuration.

Modify config/onap/values.yaml and config/robot/values.yaml. Adjust configuration parameters to you environment. In order to generate encrypted password use enc_passwd.sh script located in *utils/* directory.

**Note!** Please note that config/onap/values.yaml is the most important config file of OOM. You can choose there which components of ONAP will be installed and configuration of OpenStack is also saved there. So each configuration changes made in this file later must be rebuild ( step 7)

Remember to modify below presented parameters in config/robot/values.yaml. They are changed every time new ONAP stack is created:

`openStackPrivateNetId: "49911737-02ad-48b6-8400-3803b2b72843"`

`openStackSecurityGroup: "onap_sg_rNES"`

`openStackPrivateSubnetId: "c978ce96-de15-4ca6-8c65-26b827110df7"`

Next copy values

`cp config/onap/values.yaml oom/kubernetes/onap/values.yaml`

`cp config/robot/values.yaml oom/kubernetes/robot/values.yaml`

Make sure that oom/kubernetes/robot/demo-k8s.sh and oom/kubernetes/robot/ete-k8s.sh are runnable.

`chmod +x oom/kubernetes/robot/demo-k8s.sh`

`chmod +x om/kubernetes/robot/ete-k8s.sh`

When all the above steps are completed and all scratch are ready to install we can start proceeding installation process using Helm package system.

Install the Helm Tiller application and initialize with:

`helm init`

Helm is able to use charts served up from a repository and comes setup with a default CNCF provided Curated applications for Kubernetes repository called stable which should be removed to avoid confusion:

`helm repo remove stable`

`cd oom/kubernetes`

To setup a local Helm server to server up the ONAP charts:

`helm init`

`helm serve &`

Note the port number that is listed and use it in the Helm repo add as follows:

`helm repo add local http://127.0.0.1:8879`

To get a list of all of the available Helm chart repositories:

`helm repo list`

Then build your local Helm repository: 

`make all`

This step will take about 5-10 minutes.

The Helm search command reads through all of the repositories configured on the system, and looks for matches:

`helm search -l`

In any case, setup of the Helm repository is a one time activity.

Next, install Helm Plugins required to deploy the ONAP Casablanca release:

`cp -R helm/plugins/ ~/.helm`

Once the repo is setup, installation of ONAP can be done with a single command:

`helm install local/onap -n onap --namespace onap –f values.yaml`

This will install ONAP from a local. 

If install command is not working properly, please use deploy command:

`helm deploy onap local/onap --namespace onap -f values.yaml`

The installation process will start. It takes about 1h to complete. Then, you should have all ONAP services up and running. You can all the time observe progress of launching containers by watching resources:

`watch "kubectl get pods -n onap |grep -v Running"`

Above command will show all the Not Running containers yet. Please note that some of containers status won’t be  ‘Running’ status at all. Especially these ones with configuration aims.

To get a summary of the status of all of the pods (containers) running in your deployment:

`kubectl get pods --all-namespaces -o=wide`

ONAP is changing very dynamically, therefore some containers can not working properly. The latest correct Casablanca configuration you can find here: http://10.254.188.33/panekgr1/onap-casablanca-offline.git

After installation process is done go to robot directory and run below script.

`./ete-k8s.sh onap health`

Robot is connecting with all ONAP apps and checking if they up and running,after this test all of ONAP components should be available.

The next step is to configure ONAP instance. In Robot directory execute commands in the following order:

`cd oom/kubernetes/robot/`

`./demo-k8s.sh onap distribute`

`./demo-k8s.sh onap init`

### More information ###

Additional tips and instructions you can find on official ONAP sites:

https://onap.readthedocs.io/en/beijing/submodules/oom.git/docs/index.html

https://onap.readthedocs.io/en/beijing/submodules/oom.git/docs/oom_quickstart_guide.html

https://onap.readthedocs.io/en/beijing/submodules/oom.git/docs/oom_user_guide.html

