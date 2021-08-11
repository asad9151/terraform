control "CFP lambdas" do
  impact 1.0
  title "Lambda: CFP"

  describe aws_lambda('irsch_q1_CfpSftpOutboundDelivery') do
    it { should exist }
    its('handler') { should eq 'lambdas.stpdelivery.stpOutboundDeliveryLambda.handler' }
    its('runtime') { should eq 'python3.7'}
  end

  describe aws_lambda('irsch_q1a_CfpSftpOutboundDelivery') do
    it { should exist }
    its('handler') { should eq 'lambdas.stpdelivery.stpOutboundDeliveryLambda.handler' }
    its('runtime') { should eq 'python3.7'}
  end

  describe aws_lambda('irsch_q2_CfpSftpOutboundDelivery') do
    it { should exist }
    its('handler') { should eq 'lambdas.stpdelivery.stpOutboundDeliveryLambda.handler' }
    its('runtime') { should eq 'python3.7'}
  end

  describe aws_lambda('irsch_q2a_CfpSftpOutboundDelivery') do
    it { should exist }
    its('handler') { should eq 'lambdas.stpdelivery.stpOutboundDeliveryLambda.handler' }
    its('runtime') { should eq 'python3.7'}
  end

  describe aws_lambda('irsch_pd_CfpSftpOutboundDelivery') do
    it { should exist }
    its('handler') { should eq 'lambdas.stpdelivery.stpOutboundDeliveryLambda.handler' }
    its('runtime') { should eq 'python3.7'}
  end
end
