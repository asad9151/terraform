console.log('Loading function');
var emailFromAddress = process.env.FromAddress != null? process.env.FromAddress : "iResearchCWAlerts@dnb.com";
var emailToAddress = process.env.ToAddress != null? process.env.ToAddress : "IRSCHTeamGIT@DNB.com";
var rdsEventsWeRInterestedIn = ["RDS-EVENT-0006","RDS-EVENT-0004","RDS-EVENT-0022","RDS-EVENT-0003","RDS-EVENT-0034","RDS-EVENT-0013","RDS-EVENT-0015","RDS-EVENT-0065","RDS-EVENT-0049","RDS-EVENT-0050","RDS-EVENT-0051","RDS-EVENT-0055","RDS-EVENT-0056","RDS-EVENT-0158","RDS-EVENT-0045","RDS-EVENT-0046","RDS-EVENT-0057","RDS-EVENT-0062","RDS-EVENT-0063","RDS-EVENT-0020","RDS-EVENT-0021","RDS-EVENT-0023","RDS-EVENT-0052","RDS-EVENT-0053","RDS-EVENT-0066","RDS-EVENT-0008","RDS-EVENT-0019"];
exports.handler = function(event, context, callback) {
	
    var message = event.Records[0].Sns.Message;
	console.log('Message received from SNS:', message);
	try{//parse to check if the message recieved is a JSON or not
		JSON.parse(message);
	}catch(exception){
		console.log("Message Recieved:" + message);
		callback(null, "Success");
	}
	message = JSON.parse(message);
	var newState,oldState,alarmName,stateChangeTime,reason,threshold,actualMonitorValue,actualValueReportedByMonitor,size,dimensionsName="", dimensionsValue="",smtpHost="smtp-gw.us.dnb.com";
	var rdsSourceId,rdsEventMessage;
	//differentiate between a RDS event and a cloudwatch event
	if(message.hasOwnProperty('AlarmName')){//this will be a cloudwatch event
		newState = message.NewStateValue;
		oldState = message.OldStateValue;
		alarmName = message.AlarmName;
		stateChangeTime = message.StateChangeTime;
		reason = message.NewStateReason;
		threshold = message.Trigger.Threshold;
		actualMonitorValue = threshold;//this is the actual value for which we have configured 75% threshold on
		actualValueReportedByMonitor = null;
		size = message.Trigger.Dimensions.length;
		for(var i=0;i<size;i++){
			dimensionsName = message.Trigger.Dimensions[i].name;
			if(["DomainName","FunctionName","QueueName","DBInstanceIdentifier"].includes(dimensionsName)){
				dimensionsValue = message.Trigger.Dimensions[i].value;
				if(dimensionsName == "FunctionName"){//only for lambda function
					//will split the reason message to get the value reported from monitor
					var startIndexOfSquareBrace = reason.indexOf("[") + 1;
					var endIndexOfSquareBrace = reason.indexOf("]");
					var valueBetweenSquareBraces = reason.substr(startIndexOfSquareBrace,endIndexOfSquareBrace - startIndexOfSquareBrace);
					var spaceSeperatedListBetweenSquareBrances = valueBetweenSquareBraces.split(" ");
					actualValueReportedByMonitor = spaceSeperatedListBetweenSquareBrances[0];
				}
			}
		}
		var delimiter = dimensionsValue.substr(5,1);
		var dimensiosValueSplit = dimensionsValue.split(delimiter);
		var environment = dimensiosValueSplit[1].toUpperCase();
		smtpHost = environment.startsWith("D")?"10.241.8.38":"smtp-gw.us.dnb.com";
	} else if(message.hasOwnProperty('Event Source') && message['Event Source'] == 'db-instance'){//this is from RDS event subscription
		var rdsEvent = message['Event ID'].split("#")[1];
		if(rdsEventsWeRInterestedIn.includes(rdsEvent)){
			rdsSourceId = message['Source ID'];
			rdsEventMessage = message['Event Message'];
		}
	}
	if(dimensionsValue != ""){
		console.log("AlarmName: "+alarmName+" NewState: "+newState+" OldState: "+oldState+" StateChangeTime: "+stateChangeTime);
		if(!((newState == 'OK' && oldState == 'INSUFFICIENT_DATA') || (newState == 'INSUFFICIENT_DATA' && oldState == 'OK'))){
			console.log("These are not from INSUFFICIENT_DATA states");
			var emailBody = "", emailSubject = "";
			
			if(alarmName.includes("logsdomain") && alarmName.includes("FreeStorageSpace")) { //if the alert is from ELASTIC SEARCH update the subject appropriately
				var comparisonOperationNThreshold = alarmName.split("_")[6];
				var comparisonOperator = comparisonOperationNThreshold.substr(comparisonOperationNThreshold,comparisonOperationNThreshold.length-2);
				var threshold = comparisonOperationNThreshold.substr(comparisonOperationNThreshold.length-2);
				if(comparisonOperator == "LessThanOrEqualTo" && threshold == 25)
					emailSubject = "["+environment+"] WARNING: Elastic Search Domain Storage usage has crossed 75%, but OK";
				else if(comparisonOperator == "LessThanOrEqualTo" && threshold == 10)
					emailSubject = "["+environment+"] ALERT: Elastic Search Domain Storage usage has reached 90%";
			} else { // For lambda function and RDS event alerts
				//Generate the appropriate subject
				if(actualValueReportedByMonitor != null && actualValueReportedByMonitor >= actualMonitorValue) 
					emailSubject = "["+environment+"] ALERT: Lambda Function "+dimensionsValue+" execution timed out";
				//warning when 75% of threshold reached commented out
				//else if(actualValueReportedByMonitor != null && actualValueReportedByMonitor > threshold && actualValueReportedByMonitor < actualMonitorValue)
					//emailSubject = "["+environment+"] WARNING: Lambda Function "+dimensionsValue+" execution time crossed the threshold, but OK";
				else if(newState == 'OK' || (newState == 'INSUFFICIENT_DATA' && oldState == 'ALARM'))
					emailSubject = "["+environment+"] OK: Monitor "+alarmName+" state is back to normal";
				else
					emailSubject = "["+environment+"] Alarm State changed to "+newState+" => \""+alarmName+"\"";
			}
			
			//Generate the appropriate body
			emailBody =  "===================================================================== <br/>"
							+"<b>Alarm Name:</b> "+alarmName+"<br/>"
							+((oldState == "ALARM")?
							"<b>OldState:</b> <font color='red'>"+oldState+"</font><br/>":"<b>OldState:</b> <font color='green'>"+oldState+"</font><br/>")
							+((newState == "ALARM")?
							"<b>NewState:</b> <font color='red'>"+newState+"</font><br/>":"<b>NewState:</b> <font color='green'>"+newState+"</font><br/>")
							+"<b>StateChangeTime:</b> "+stateChangeTime+"<br/>"
							+"<b>Reason for the state change:</b> "+reason+"<br/>"
							+"<b>Threshold value of the alarm:</b> "+threshold+"<br/>"
							+"===================================================================== <br/><br/>"
							+"<i>This is an auto-generated mail. Please don't reply to this mail directly. <br/>"
							+"In case of any questions, please contact the support group.</i>";
			
			console.log("Email Subject: " + emailSubject);					
			if(! (emailSubject == "["+environment+"] WARNING: Elastic Search Domain Storage usage has crossed 75%, but OK")) //Skipping the email on less than 25% space
			{
				console.log("sending the email now");
				sendEmail(emailFromAddress,emailToAddress,emailSubject,emailBody,smtpHost);//Send the email Now
			}
				
		}
	} else if(rdsEventMessage != ""){
		emailSubject = rdsSourceId+" : RDS Event Message Notification";
		emailBody =  "===================================================================== <br/>"
							+"<b>Follwing message is generated from RDS:</b> "+rdsEventMessage+"<br/>"
							+"===================================================================== <br/><br/>"
							+"<i>This is an auto-generated mail. Please don't reply to this mail directly. <br/>"
							+"In case of any questions, please contact the support group.</i>";
		sendEmail(emailFromAddress,emailToAddress,emailSubject,emailBody,smtpHost);
	} else {
		console.log("Something went wrong in processing the request - Please check");
	}
    callback(null, "Success");
};
function sendEmail(emailFrom,emailTo,subjectText,body,smtpHost){

	var nodemailer = require('nodemailer');

	// create reusable transporter object using the default SMTP transport
	var transporter = nodemailer.createTransport({
		  //host: "mftctofwftp.dnb.com",
		  host: smtpHost,
		  port: 25,
		  secure: false // upgrade later with STARTTLS
		});

	// setup e-mail data with unicode symbols
	var mailOptions = {
		from: emailFrom, // sender address
		to: emailTo, // list of receivers
		subject: subjectText, // Subject line
		//text: body, // plaintext body
		html: body // html body
	};

	// send mail with defined transport object
	transporter.sendMail(mailOptions, function(error, info){
		if(error){
			return console.log(error);
		}
		console.log('E-Mail Message sent: ' + info.response);
	});
}