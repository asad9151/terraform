control "Ascent Exclusions Queue" do
  impact 1.0
  title 'Queue: Ascent Exclusions'

  describe aws_sqs_queue('https://sqs.us-east-1.amazonaws.com/292120075268/irsch_q1_sendUpdateToAscentExclusions') do
    it { should exist }
  end

  describe aws_sqs_queue('https://sqs.us-east-1.amazonaws.com/292120075268/irsch_q1a_sendUpdateToAscentExclusions') do
    it { should exist }
  end

  describe aws_sqs_queue('https://sqs.us-east-1.amazonaws.com/292120075268/irsch_q2_sendUpdateToAscentExclusions') do
    it { should exist }
  end

  describe aws_sqs_queue('https://sqs.us-east-1.amazonaws.com/292120075268/irsch_q2a_sendUpdateToAscentExclusions') do
    it { should exist }
  end

  describe aws_sqs_queue('https://sqs.us-east-1.amazonaws.com/292120075268/irsch_pd_sendUpdateToAscentExclusions') do
    it { should exist }
  end
end

control "Ascent Violations Queue" do
  impact 1.0
  title 'Queue: Ascent Violations'

  describe aws_sqs_queue('https://sqs.us-east-1.amazonaws.com/292120075268/irsch_q1_sendUpdateToAscentViolations') do
    it { should exist }
  end

  describe aws_sqs_queue('https://sqs.us-east-1.amazonaws.com/292120075268/irsch_q1a_sendUpdateToAscentViolations') do
    it { should exist }
  end

  describe aws_sqs_queue('https://sqs.us-east-1.amazonaws.com/292120075268/irsch_q2_sendUpdateToAscentViolations') do
    it { should exist }
  end

  describe aws_sqs_queue('https://sqs.us-east-1.amazonaws.com/292120075268/irsch_q2a_sendUpdateToAscentViolations') do
    it { should exist }
  end

  describe aws_sqs_queue('https://sqs.us-east-1.amazonaws.com/292120075268/irsch_pd_sendUpdateToAscentViolations') do
    it { should exist }
  end
end


control "SubmitToRemoteApp Queue" do
  impact 1.0
  title 'Queue: SubmitToRemoteApp'

  describe aws_sqs_queue('https://sqs.us-east-1.amazonaws.com/292120075268/irsch_q1_sendToSubmitToRemoteApp') do
    it { should exist }
    its('delay_seconds') { should eq 5 }
  end

  describe aws_sqs_queue('https://sqs.us-east-1.amazonaws.com/292120075268/irsch_q1a_sendToSubmitToRemoteApp') do
    it { should exist }
    its('delay_seconds') { should eq 5 }
  end

  describe aws_sqs_queue('https://sqs.us-east-1.amazonaws.com/292120075268/irsch_q2_sendToSubmitToRemoteApp') do
    it { should exist }
    its('delay_seconds') { should eq 5 }
  end

  describe aws_sqs_queue('https://sqs.us-east-1.amazonaws.com/292120075268/irsch_q2a_sendToSubmitToRemoteApp') do
    it { should exist }
    its('delay_seconds') { should eq 5 }
  end

  describe aws_sqs_queue('https://sqs.us-east-1.amazonaws.com/292120075268/irsch_pd_sendToSubmitToRemoteApp') do
    it { should exist }
    its('delay_seconds') { should eq 5 }
  end
end
