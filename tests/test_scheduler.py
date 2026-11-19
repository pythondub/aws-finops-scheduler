import os
import boto3
import pytest
from moto import mock_aws
from src.scheduler import lambda_handler


@pytest.fixture(autouse=True)
def aws_credentials(monkeypatch):
    """Ізоляція від реального AWS SSO профілю."""
    monkeypatch.delenv("AWS_PROFILE", raising=False)
    monkeypatch.setenv("AWS_ACCESS_KEY_ID", "testing")
    monkeypatch.setenv("AWS_SECRET_ACCESS_KEY", "testing")
    monkeypatch.setenv("AWS_SECURITY_TOKEN", "testing")
    monkeypatch.setenv("AWS_SESSION_TOKEN", "testing")
    monkeypatch.setenv("AWS_REGION", "eu-west-1")


def _create_instance(ec2_client, tags=None):
    params = {
        "ImageId": "ami-12345678",
        "MinCount": 1,
        "MaxCount": 1,
        "InstanceType": "t3.micro",
    }
    if tags:
        params["TagSpecifications"] = [{"ResourceType": "instance", "Tags": tags}]
    resp = ec2_client.run_instances(**params)
    return resp["Instances"][0]["InstanceId"]


@mock_aws
def test_dry_run_does_not_stop_instances(monkeypatch):
    ec2 = boto3.client("ec2", region_name="eu-west-1")
    target_id = _create_instance(ec2, tags=[{"Key": "AutoStop", "Value": "True"}])

    monkeypatch.setenv("DRY_RUN", "true")
    result = lambda_handler({}, None)

    assert result["status"] == "dry_run_success"
    assert target_id in result["target_instances"]

    # Перевірка, що інстанс реально залишився запущеним
    state = ec2.describe_instances(InstanceIds=[target_id])["Reservations"][0]["Instances"][0]["State"]["Name"]
    assert state == "running"


@mock_aws
def test_opt_in_stops_only_tagged_instances(monkeypatch):
    ec2 = boto3.client("ec2", region_name="eu-west-1")
    target_id = _create_instance(ec2, tags=[{"Key": "AutoStop", "Value": "True"}])
    prod_id = _create_instance(ec2, tags=[{"Key": "Env", "Value": "Prod"}])

    monkeypatch.setenv("DRY_RUN", "false")
    result = lambda_handler({}, None)

    assert result["status"] == "stopped"
    assert result["stopped_instances"] == [target_id]

    # Перевірка станів обох інстансів
    states = {
        inst["InstanceId"]: inst["State"]["Name"]
        for res in ec2.describe_instances()["Reservations"]
        for inst in res["Instances"]
    }
    assert states[target_id] == "stopped"
    assert states[prod_id] == "running"