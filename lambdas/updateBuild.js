const AWS = require("aws-sdk");

exports.handler = async (event) => {
  const instances = await getInstancesInAutoScalingGroup("jobify-asg");

  for (const instanceId of instances) {
    await updateAndRestartInstance(instanceId);
  }
};

async function getInstancesInAutoScalingGroup(asgName) {
  const autoScaling = new AWS.AutoScaling();
  const params = {
    AutoScalingGroupNames: [asgName],
  };
  const data = await autoScaling.describeAutoScalingGroups(params).promise();
  return data.AutoScalingGroups[0].Instances.map((i) => i.InstanceId);
}

async function updateAndRestartInstance(instanceId) {
  const ssm = new AWS.SSM();
  const command = `
      aws s3 cp s3://jobify-artifacts-bucket/backend-code.zip /tmp/backend-code.zip
      unzip -o /tmp/backend-code.zip -d /var/www/html
      rm /tmp/backend-code.zip
      systemctl restart myapp.service
    `;

  const params = {
    DocumentName: "AWS-RunShellScript",
    InstanceIds: [instanceId],
    Parameters: {
      commands: [command],
    },
  };
  await ssm.sendCommand(params).promise();
}
