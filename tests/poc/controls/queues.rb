control "SubmitToRemoteApp Queue" do
  impact 1.0
  title 'Queue: SubmitToRemoteApp'

  describe aws_sqs_queue('https://sqs.us-east-1.amazonaws.com/486031490454/irsch_d2_sendToSubmitToRemoteApp') do
    it { should exist }
    its('delay_seconds') { should eq 5 }
  end
end
