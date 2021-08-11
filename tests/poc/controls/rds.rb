control "MySQL Upgrade Database" do
  impact 1.0
  title 'Database: MySQL Upgrade'

  describe aws_rds_instance('iresearch-test') do
    it { should exist }
    its('engine') { should eq 'mysql' }
    its('engine_version') { should eq '8.0.20' }
  end
end

control "Performance Database" do
  impact 1.0
  title 'Database: Performance'

  describe aws_rds_instance('iresearch-performance') do
    it { should exist }
    its('engine') { should eq 'mysql' }
    its('engine_version') { should eq '5.7.22' }
  end
end

control "Random DBA Database" do
  impact 1.0
  title 'Database: Random DBA'

  describe aws_rds_instance('iresearch-dbatemp') do
    it { should_not exist }
  end
end
