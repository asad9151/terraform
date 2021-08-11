control "Ascent Violations Access Keys" do
  impact 1.0
  title "API Access Keys: Ascent Violations"

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-AscentViolations-d2', id: 'AKIAXCKN37WLP2MBNY4D') do
    it { should exist }
    it { should be_active }
  end
end

control "Deploy App Access Keys" do
  impact 1.0
  title "AWS Access Key: Deploy App"

  describe aws_iam_access_key(username: 'svc_irschdeployapp-d2', id: 'AKIAJULMFHR5V6KG7T2Q') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschdeployapp-d3', id: 'AKIAJBFFQ2KBLKKFZOUA') do
    it { should exist }
    it { should be_active }
  end
end

control "Jenkins Shutdown Resources Access Keys" do
  impact 1.0
  title "AWS Access Key: Jenkins Shutdown Resources"

  describe aws_iam_access_key(username: 'svc_irschjenkinsInfra-d2', id: 'AKIAXCKN37WLDTX35APK') do
    it { should exist }
    it { should be_active }
  end
end
