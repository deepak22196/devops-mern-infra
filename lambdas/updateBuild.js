const AWS = require("aws-sdk");

exports.handler = async (event) => {
  const instances = await getInstancesInAutoScalingGroup("jobify-asg");

  for (const instanceId of instances) {
    console.log(`Updating and restarting instance: ${instanceId}`);
    await updateAndRestartInstance(instanceId);
  }
};

async function getInstancesInAutoScalingGroup(asgName) {
  const autoScaling = new AWS.AutoScaling();
  const params = {
    AutoScalingGroupNames: [asgName],
  };
  const data = await autoScaling.describeAutoScalingGroups(params).promise();
  const instanceIds = data.AutoScalingGroups[0].Instances.map(
    (i) => i.InstanceId
  );

  console.log(
    `Found instances in Auto Scaling Group ${asgName}: ${instanceIds}`
  );

  return instanceIds;
}

async function updateAndRestartInstance(instanceId) {
  const ssm = new AWS.SSM();
  const command = `
      cd /home/ec2-user
      sudo aws s3 cp s3://jobify-artifacts-bucket/backend-code.zip ./backend-code.zip
      sudo unzip -o /home/ec2-user/backend-code.zip -d /home/ec2-user/jobify-server
      sudo rm ./backend-code.zip
      // systemctl restart jobify.service
      cd jobify-server
      npm install
      cd ..
      # Create the systemd service file
      cat <<EOT > jobify.service
      [Unit]
      Description=jobify backend app
      After=network.target

      [Service]
      ExecStart=/usr/bin/npm /home/ec2-user/jobify-server/server.js
      Restart=always
      User=nobody
      Group=nobody
      Environment=PATH=/usr/bin:/usr/local/bin
      Environment=NODE_ENV=production
      WorkingDirectory=/home/ec2-user/jobify-server

      [Install]
      WantedBy=multi-user.target
      EOT

      sudo mv /home/ec2-user/jobify.service /etc/systemd/system/

      # Reload systemd, enable and start the service
      sudo systemctl daemon-reload
      sudo systemctl enable jobify.service
      sudo systemctl start jobify.service

    `;

  const params = {
    DocumentName: "AWS-RunShellScript",
    InstanceIds: [instanceId],
    Parameters: {
      commands: [command],
    },
  };

  console.log(`Sending command to instance ${instanceId}: ${command}`);

  await ssm.sendCommand(params).promise();
  console.log(`Command sent successfully to instance ${instanceId}`);
}
