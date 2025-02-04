// Create a security Group
resource "aws_security_group" "Enrich" {
  name = "snowplow-enrich-sg"

  # tags {
  #   Name = "snowplow-enrich-sg"
  # }

  ingress {
    from_port   = "22"
    to_port     = "22"
    protocol    = "TCP"
    # cidr_blocks = ["${var.my_ip}/32"]
    cidr_blocks = ["${var.my_ip}/0"]
  }

  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

// Create a new instance
resource "aws_instance" "Enrich" {
  ami = "ami-14b5a16d"
  instance_type = "t2.micro"
  key_name = "${var.key_name}"
  security_groups = ["${aws_security_group.Enrich.name}"]
  iam_instance_profile = "${aws_iam_instance_profile.Enrich.name}"

  tags = {
    Name = "snowplow-enrich"
  }

  root_block_device {
    volume_type = "standard"
    volume_size = 100
    delete_on_termination = true
  }

  provisioner "file" {
    source      = "./enrich"
    destination = "~/enrich"

    connection {
      user = "ec2-user"
      private_key = "${file(var.key_path)}"
      host = aws_instance.Enrich.public_ip
    }
  }

  provisioner "remote-exec" {
    inline = [
      "cd ~/enrich",
      "cp config.hocon.sample config.hocon",
      "sed -i -e 's/{{enrichStreamsInRaw}}/${aws_kinesis_stream.CollectorGood.name}/g' config.hocon",
      "sed -i -e 's/{{enrichStreamsBufferByteThreshold}}/${var.enrich_stream_in_byte_thresh}/g' config.hocon",
      "sed -i -e 's/{{enrichStreamsBufferRecordThreshold}}/${var.enrich_stream_in_record_thresh}/g' config.hocon",
      "sed -i -e 's/{{enrichStreamsBufferTimeThreshold}}/${var.enrich_stream_in_time_thresh}/g' config.hocon",
      "sed -i -e 's/{{enrichStreamsOutEnriched}}/${aws_kinesis_stream.EnrichGood.name}/g' config.hocon",
      "sed -i -e 's/{{enrichStreamsOutBad}}/${aws_kinesis_stream.EnrichBad.name}/g' config.hocon",
      "sed -i -e 's/{{enrichStreamsOutMinBackoff}}/${var.enrich_stream_out_min_backoff}/g' config.hocon",
      "sed -i -e 's/{{enrichStreamsOutMaxBackoff}}/${var.enrich_stream_out_max_backoff}/g' config.hocon",
      # "sed -i -e 's/{{enrichStreamsAppName}}/${aws_dynamodb_table.EnrichApp.name}/g' config.hocon",
      "sed -i -e 's/{{enrichStreamsAppName}}/${var.enrich_app_name}/g' config.hocon",
      "sed -i -e 's/{{enrichStreamsRegion}}/${var.aws_region}/g' config.hocon",
      # "wget https://dl.bintray.com/snowplow/snowplow-generic/snowplow_stream_enrich_${var.enrich_version}.zip",
      # "unzip snowplow_stream_enrich_${var.enrich_version}.zip",
      # "wget https://bintray.com/snowplow/snowplow-generic/download_file?file_path=snowplow_scala_stream_enrich_${var.data_stream}_${var.enrich_version}.zip -O snowplow_scala_stream_enrich_${var.data_stream}_${var.enrich_version}.zip",
      "wget https://bintray.com/snowplow/snowplow-generic/download_file?file_path=snowplow_stream_enrich_${var.data_stream}_${var.enrich_version}.zip -O snowplow_stream_enrich_${var.data_stream}_${var.enrich_version}.zip",
      "unzip snowplow_stream_enrich_${var.data_stream}_${var.enrich_version}.zip",
      # "chmod +x snowplow-stream-enrich-${var.enrich_version}",
      # "sudo nohup ./snowplow-stream-enrich-${var.enrich_version} --config config.hocon --resolver resolver.json &",
      # "sudo nohup java -Dcom.amazonaws.sdk.disableCbor -jar snowplow-stream-enrich-${var.data_stream}-${var.enrich_version}.jar --config config.hocon > foo.log 2>&1 &",
      "sudo nohup java -jar snowplow-stream-enrich-${var.data_stream}-${var.enrich_version}.jar --config config.hocon --resolver file:resolver.json > foo.log 2>&1 &",
      "sleep 30"
    ]

    connection {
      user = "ec2-user"
      private_key = "${file(var.key_path)}"
      host = aws_instance.Enrich.public_ip
    }
  }
}
