control "RDS instances" do
  impact 1.0
  title "RDS instances"

  describe aws_rds_instance(db_instance_identifier: 'irsch-stg') do
    it { should exist }
    its('engine') { should eq 'mysql' }
    its('engine_version') { should eq '5.7.22' }
    its('storage_type') { should eq 'gp2' }
    its('db_instance_class') { should eq 'db.m5.large'}
  end

  describe aws_rds_instance(db_instance_identifier: 'irsch-qa') do
    it { should exist }
    its('engine') { should eq 'mysql' }
    its('engine_version') { should eq '5.7.22' }
    its('storage_type') { should eq 'gp2' }
    its('db_instance_class') { should eq 'db.m5.large' }
  end

  describe aws_rds_instance(db_instance_identifier: 'irsch-pd') do
    it { should exist }
    its('engine') { should eq 'mysql' }
    its('engine_version') { should eq '5.7.22' }
    its('storage_type') { should eq 'gp2' }
    its('db_instance_class') { should eq 'db.m4.2xlarge'}
  end
end
