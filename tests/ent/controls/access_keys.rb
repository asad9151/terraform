control "Altares (Benelux) Access Keys" do
  impact 1.0
  title "API Access Key: Altares (Benelux)"

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-Altares-Benelux-q1') do
    it { should_not exist }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-Altares-Benelux-q1a') do
    it { should_not exist }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-Altares-Benelux-q2', id: 'AKIAUIA5WTQCK4KB4K4Q') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-Altares-Benelux-q2a') do
    it { should exist }
    its('access_keys') { should be_empty }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-Altares-Benelux-pd', id: 'AKIAUIA5WTQCD4MHGSJ3') do
    it { should exist }
    it { should be_active }
  end
end

control "Altares (France) Access Keys" do
  impact 1.0
  title "API Access Key: Altares (France)"

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-Altares-FRA-q1') do
    it { should_not exist }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-Altares-FRA-q1a') do
    it { should_not exist }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-Altares-FRA-q2', id: 'AKIAUIA5WTQCIAOPMSWR') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-Altares-FRA-q2a') do
    it { should exist }
    its('access_keys') { should be_empty }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-Altares-FRA-pd', id: 'AKIAUIA5WTQCEAKJ3YER') do
    it { should exist }
    it { should be_active }
  end
end

control "App Team Access Keys" do
  impact 1.0
  title "API Access Keys: Application Team"

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-appTeam-q1', id: 'AKIAUIA5WTQCAJTHC6OK') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-appTeam-q1a', id: 'AKIAUIA5WTQCF4PFB5MP') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-appTeam-q2', id: 'AKIAUIA5WTQCAYS5N5XA') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-appTeam-q2a', id: 'AKIAUIA5WTQCGGGJE4GL') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-appTeam-pd', id: 'AKIAUIA5WTQCJ3DDIAI2') do
    it { should exist }
    it { should be_active }
  end
end

control "Ascent Exclusions Access Keys" do
  impact 1.0
  title "API Acess Keys: Ascent Exclusions"

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-AscentExclusions-q1') do
    it { should exist }
    its('access_keys') { should be_empty }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-AscentExclusions-q1a', id: 'AKIAUIA5WTQCKIJLPNN5') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-AscentExclusions-q2', id: 'AKIAUIA5WTQCIGFXCRU2') do
    it { should exist }
    it { should be_active }
  end 

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-AscentExclusions-q2a', id: 'AKIAUIA5WTQCA5BU54D5') do
    it { should exist }
    it { should be_active }
  end 

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-AscentExclusions-pd', id: 'AKIAUIA5WTQCFQ6LP3KS') do
    it { should exist }
    it { should be_active }
  end 
end

control "Ascent Violations Access Keys" do
  impact 1.0
  title "API Access Keys: Ascent Violations"

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-AscentViolations-q1', id: 'AKIAUIA5WTQCCA36LNGM') do
    it { should exist }
    it { should_not be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-AscentViolations-q1a', id: 'AKIAUIA5WTQCPXTRERCM') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-AscentViolations-q2', id: 'AKIAUIA5WTQCB7RVFVPH') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-AscentViolations-q2a', id: 'AKIAUIA5WTQCG6DDQHEB') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-AscentViolations-pd') do
    it { should exist }
    its('access_keys') { should_not be_empty }
  end
end

control "BDRS Access Keys" do
  impact 1.0
  title "API Access Keys: BDRS"

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-BDRSTeam-q1', id: 'AKIAUIA5WTQCHCH6GT4N') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-BDRSTeam-q1a') do
    it { should exist }
    its('access_keys') { should be_empty }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-BDRSTeam-q2') do
    it { should_not exist }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-BDRSTeam-q2a') do
    it { should_not exist }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-BDRSTeam-pd') do
    it { should_not exist }
  end
end

control "BizNode (AUT) Access Keys" do
  impact 1.0
  title "API Access Keys: BizNode"

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-BizNode-AUT-q1') do
    it { should_not exist }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-BizNode-AUT-q1a') do
    it { should_not exist }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-BizNode-AUT-q2', id: 'AKIAUIA5WTQCPR5FXV77') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-BizNode-AUT-q2a') do
    it { should  exist }
    its('access_keys') { should be_empty }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-BizNode-AUT-pd', id: 'AKIAUIA5WTQCNXMJUU6C') do
    it { should exist }
    it { should be_active }
  end
end

control "BizNode (CHE) Access Keys" do
  impact 1.0
  title "API Access Keys: BizNode (CHE)"

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-BizNode-CHE-q1') do
    it { should_not exist }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-BizNode-CHE-q1a') do
    it { should_not exist }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-BizNode-CHE-q2', id: 'AKIAUIA5WTQCNHANUWVD') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-BizNode-CHE-q2a') do
    it { should exist }
    its('access_keys') { should be_empty }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-BizNode-CHE-pd', id: 'AKIAUIA5WTQCNXNKUNPP') do
    it { should exist }
    it { should be_active }
  end
end

control "BizNode (DEU) Access Keys" do
  impact 1.0
  title "API Access Keys: BizNode (DEU)"

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-BizNode-DEU-q1') do
    it { should_not exist }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-BizNode-DEU-q1a') do
    it { should_not exist }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-BizNode-DEU-q2', id: 'AKIAUIA5WTQCOX4PCMG2') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-BizNode-DEU-q2a') do
    it { should exist }
    its('access_keys') { should be_empty }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-BizNode-DEU-pd', id: 'AKIAUIA5WTQCHWUERYO2') do
    it { should exist }
    it { should be_active }
  end
end

control "China (Taiwan) Access Keys" do
  impact 1.0
  title "API Access Key: China (Taiwan)"

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-chinaTeam-q1') do
    it { should exist }
    its('access_keys') { should be_empty }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-chinaTeam-q1a') do
    it { should exist }
    its('access_keys') { should be_empty }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-chinaTeam-q2', id: 'AKIAUIA5WTQCDV475MIX') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-chinaTeam-q2a') do
    it { should exist }
    its('access_keys') { should be_empty }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-chinaTeam-pd', id: 'AKIAUIA5WTQCAFDG2S55') do
    it { should exist }
    it { should be_active }
  end
end

control "Cribis Access Keys" do
  impact 1.0
  title "API Access Keys: Cribis"

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-Cribis-q1') do
    it { should_not exist }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-Cribis-q1a') do
    it { should_not exist }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-Cribis-q2', id: 'AKIAUIA5WTQCBUQRMFHC') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-Cribis-q2a') do
    it { should exist }
    its('access_keys') { should be_empty }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-Cribis-pd', id: 'AKIAUIA5WTQCM62VNMHQ') do
    it { should exist }
    it { should be_active }
  end
end

control "Deploy App Access Keys" do
  impact 1.0
  title "AWS Access Keys: Deploy App"

  describe aws_iam_access_key(username: 'svc_irschdeployapp-q1', id: 'AKIAJWF44EPZVTKCTVYQ') do
    it { should exist }
    it { should be_active }
  end
  describe aws_iam_access_key(username: 'svc_irschdeployapp-q1a', id: 'AKIAUIA5WTQCOP4TUBN2') do
    it { should exist }
    it { should be_active }
  end
  describe aws_iam_access_key(username: 'svc_irschdeployapp-q2', id: 'AKIAUIA5WTQCD72WYNFX') do
    it { should exist }
    it { should be_active }
  end
  describe aws_iam_access_key(username: 'svc_irschdeployapp-q2a', id: 'AKIAUIA5WTQCOQGF32EK') do
    it { should exist }
    it { should be_active }
  end
  describe aws_iam_access_key(username: 'svc_irschdeployapp-pd', id: 'AKIAISBOA6AXVRIC7PIQ') do
    it { should exist }
    it { should be_active }
  end
  describe aws_iam_access_key(username: 'svc_irschdeployapp-dr', id: 'AKIAUIA5WTQCOEUXTL5O') do
    it { should exist }
    it { should be_active }
  end

end

control "Direct+ Access Keys" do
  impact 1.0
  title "API Access Keys: Direct+"

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-directPlusTeam-q1', id: 'AKIAUIA5WTQCGMMH44H5') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-directPlusTeam-q1a', id: 'AKIAUIA5WTQCHU4ZSKKH') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-directPlusTeam-q2', id: 'AKIAUIA5WTQCBK4IJCRZ') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-directPlusTeam-q2a') do
    it { should exist }
    its('access_keys') { should be_empty }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-directPlusTeam-pd', id: 'AKIAUIA5WTQCDS7Z7YHI') do
    it { should exist }
    it { should be_active }
  end
end

control "Enterprise Services Access Keys" do
  impact 1.0
  title "API Access Keys: Enterprise Services"

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-EntServicesTeam-q1') do
    it { should exist }
    its('access_keys') { should be_empty }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-EntServicesTeam-q1a') do
    it { should exist }
    its('access_keys') { should be_empty }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-EntServicesTeam-q2') do
    it { should exist }
    its('access_keys') { should be_empty }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-EntServicesTeam-q2a') do
    it { should exist }
    its('access_keys') { should be_empty }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-EntServicesTeam-pd') do
    it { should exist }
    its('access_keys') { should be_empty }
  end
end

control "ERC Access Keys" do
  impact 1.0
  title "API Access Keys: ERC"

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-erc-q1', id: 'AKIAUIA5WTQCESMHGAM2') do
    it { should exist }
    it { should_not be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-erc-q1a', id: 'AKIAUIA5WTQCAGADF5PO') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-erc-q2', id: 'AKIAUIA5WTQCJT6DFD4D') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-erc-q2a', id: 'AKIAUIA5WTQCERNOPWUP') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-erc-pd', id: 'AKIAUIA5WTQCKDSEDV5S') do
    it { should exist }
    it { should be_active }
  end
end

control "EU Services Access Keys" do
  impact 1.0
  title "API Access Keys: EU Services"

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-EUServicesTeam-q1', id: 'AKIAUIA5WTQCDJBBFHHK') do
    it { should exist }
    it { should_not be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-EUServicesTeam-q1a', id: 'AKIAUIA5WTQCMEVEGXDR') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-EUServicesTeam-q2', id: 'AKIAUIA5WTQCNWQWLEVN') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-EUServicesTeam-q2a', id: 'AKIAUIA5WTQCAZX754CP') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-EUServicesTeam-pd', id: 'AKIAUIA5WTQCKCTSTJYA') do
    it { should exist }
    it { should be_active }
  end
end

control "Mini Portal Access Keys" do
  impact 1.0
  title "API Access Keys: Mini Portal"

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-MiniPortal-q1', id: 'AKIAUIA5WTQCFSPHO47R') do
    it { should exist }
    it { should_not be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-MiniPortal-q1a', id: 'AKIAUIA5WTQCOQ3LDM6N') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-MiniPortal-q2') do
    it { should exist }
    its('access_keys') { should be_empty }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-MiniPortal-q2a') do
    it { should exist }
    its('access_keys') { should be_empty }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-MiniPortal-pd', id: 'AKIAUIA5WTQCJQGVDEVK') do
    it { should exist }
    it { should be_active }
  end
end

control "New Relic Access Keys" do
  impact 1.0
  title "API Access Keys: New Relic"

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-newRelic-q1') do
    it { should_not exist }
  end
  
  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-newRelic-q1a') do
    it { should_not exist }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-newRelic-q2') do
    it { should_not exist }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-newRelic-q2a') do
    it { should_not exist }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-newRelic-pd', id: 'AKIAUIA5WTQCOFSOQY55') do
    it { should exist }
    it { should be_active }
  end
end

control "Penetration Testing Access Keys" do
  impact 1.0
  title "API Access Keys: Penetration Testing"

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-pennTest-q1', id: 'AKIAUIA5WTQCJXRBJUKW') do
    it { should exist }
    it { should_not be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-pennTest-q1a', id: 'AKIAUIA5WTQCOUIATEZL') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-pennTest-q2') do
    it { should_not exist }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-pennTest-q2a') do
    it { should_not exist }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-pennTest-pd') do
    it { should_not exist }
  end
end

control "Salesforce Access Keys" do
  impact 1.0
  title "API Acess Key: Salesforce"

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-SFDCTeam-q1', id: 'AKIAUIA5WTQCAXSSVVOJ') do
    it { should exist }
    it { should_not be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-SFDCTeam-q1a', id: 'AKIAUIA5WTQCNVZRKIHX') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-SFDCTeam-q2', id: 'AKIAUIA5WTQCDPATPM7E') do
    it { should exist }
    it { should_not be_active }
  end

  describe aws_iam_user(user_name: 'svc_irschExecCloudServicesAPI-SFDCTeam-q2a') do
    it { should exist }
    its('access_keys') { should be_empty }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-SFDCTeam-pd', id: 'AKIAUIA5WTQCNBVNHHPS') do
    it { should exist }
    it { should be_active }
  end
end

control "Unity Access Keys" do
  impact 1.0
  title "API Access Keys: Unity"

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-unityTeam-q1', id: 'AKIAUIA5WTQCDVLWBBRR') do
    it { should exist }
    it { should_not be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-unityTeam-q1a', id: 'AKIAUIA5WTQCDR2CHSUN') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-unityTeam-q2', id: 'AKIAUIA5WTQCIQFYMC3B') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-unityTeam-q2a', id: 'AKIAUIA5WTQCK3JM7S4T') do
    it { should exist }
    it { should be_active }
  end

  describe aws_iam_access_key(username: 'svc_irschExecCloudServicesAPI-unityTeam-pd', id: 'AKIAUIA5WTQCB3OTHKO7') do
    it { should exist }
    it { should be_active }
  end
end
