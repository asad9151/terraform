control "CFP Directories" do
  impact 1.0
  title "S3 Directories for CFP: Domestic and Global"

  describe aws_s3_bucket_object(bucket_name: 'irsch-q1-datastores', key: 'sftp-users/CFPUserQ1/Domestic/DONOTDELETE') do
    it { should exist }
  end

  describe aws_s3_bucket_object(bucket_name: 'irsch-q1-datastores', key: 'sftp-users/CFPUserQ1/Global/DONOTDELETE') do
    it { should exist }
  end

  describe aws_s3_bucket_object(bucket_name: 'irsch-q1a-datastores', key: 'sftp-users/CFPUserQ1/Domestic/DONOTDELETE') do
    it { should exist }
  end

  describe aws_s3_bucket_object(bucket_name: 'irsch-q1a-datastores', key: 'sftp-users/CFPUserQ1/Global/DONOTDELETE') do
    it { should exist }
  end

  describe aws_s3_bucket_object(bucket_name: 'irsch-q2-datastores', key: 'sftp-users/CFPUserQ2/Domestic/DONOTDELETE') do
    it { should exist }
  end

  describe aws_s3_bucket_object(bucket_name: 'irsch-q2a-datastores', key: 'sftp-users/CFPUserQ2/Global/DONOTDELETE') do
    it { should exist }
  end

  describe aws_s3_bucket_object(bucket_name: 'irsch-pd-datastores', key: 'sftp-users/CFPUserPD/Domestic/DONOTDELETE') do
    it { should exist }
  end

  describe aws_s3_bucket_object(bucket_name: 'irsch-pd-datastores', key: 'sftp-users/CFPUserPD/Global/DONOTDELETE') do
    it { should exist }
  end
end
