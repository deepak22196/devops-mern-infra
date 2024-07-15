const AWS = require("aws-sdk");
const s3 = new AWS.S3();

exports.handler = async (event) => {
  const ec2 = new AWS.EC2();
  const autoScaling = new AWS.AutoScaling();

  const instances = await getInstancesInAutoScalingGroup("jobify-asg");

  for (const instanceId of instances) {
    await updateAndRestartInstance(instanceId);
  }
};

async function getInstancesInAutoScalingGroup(asgName) {
  const params = {
    AutoScalingGroupNames: [asgName],
  };
  const data = await autoScaling.describeAutoScalingGroups(params).promise();
  return data.AutoScalingGroups[0].Instances.map((i) => i.InstanceId);
}

async function updateAndRestartInstance(instanceId) {
  const ssm = new AWS.SSM();
  const command = `
      aws s3 cp s3://jobify-artifacts-bucket/build/artifact.zip /tmp/artifact.zip
      unzip -o /tmp/artifact.zip -d /var/www/html
      rm /tmp/artifact.zip
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
