node()
{ 
	cleanWs()
	//Check for only PR's going into develop
	if(env.CHANGE_ID !=null && env.CHANGE_ID != "" && env.CHANGE_TARGET !=null && env.CHANGE_TARGET != "" && env.CHANGE_TARGET == "develop"){
		node('dnb-prime-devqa-jenkins'){
			stage('checkout'){
				checkout scm
			}
			stage('terraform'){
				wrap([$class: 'AnsiColorBuildWrapper', 'colorMapName': 'xterm']) {
					sh "terraform -version"
					sh "cd ${WORKSPACE}/dev;terraform init --reconfigure -backend=false"
					def formattingResults = sh(script:"cd ${WORKSPACE}/dev;terraform fmt -check",returnStdout:true)
					if(formattingResults != null && formattingResults.length() > 0)
					{
					    currentBuild.result = 'FAILURE'
					    echo "There is an issue in the format of the scripts"
					    echo "following files are identified to be fixed"
					    echo formattingResults
					    return
					}
					sh "cd ${WORKSPACE}/dev;terraform validate -var env=d2"
				}
			}
		}
	} else {
		echo "This pipeline is only to check on PR requests going into develop branch only"
	}
} 
