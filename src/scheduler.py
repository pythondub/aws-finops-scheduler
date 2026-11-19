import logging
import os
import boto3
from botocore.exceptions import ClientError

# Налаштування логування для коректного відображення в AWS CloudWatch
logger = logging.getLogger()
logger.setLevel(logging.INFO)
if not logger.handlers:
    logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(message)s")


def get_target_instances(ec2_client, tag_key: str, tag_value: str) -> list[str]:
    """Повертає список ID запущених EC2-інстансів із заданим Opt-In тегом."""
    paginator = ec2_client.get_paginator("describe_instances")
    filters = [
        {"Name": "instance-state-name", "Values": ["running"]},
        {"Name": f"tag:{tag_key}", "Values": [tag_value]},
    ]

    instance_ids = []
    for page in paginator.paginate(Filters=filters):
        for reservation in page.get("Reservations", []):
            for instance in reservation.get("Instances", []):
                instance_ids.append(instance["InstanceId"])

    return instance_ids


def lambda_handler(event, context):
    region = os.environ.get("AWS_REGION", "eu-west-1")
    tag_key = os.environ.get("TARGET_TAG_KEY", "AutoStop")
    tag_value = os.environ.get("TARGET_TAG_VALUE", "True")
    # Fail-safe: якщо змінна не задана, за замовчуванням увімкнено DRY_RUN
    dry_run = os.environ.get("DRY_RUN", "true").lower() == "true"

    logger.info(
        "Запуск FinOps Scheduler | Регіон: %s | Фільтр: %s=%s | DRY_RUN: %s",
        region, tag_key, tag_value, dry_run
    )

    ec2 = boto3.client("ec2", region_name=region)

    try:
        instance_ids = get_target_instances(ec2, tag_key, tag_value)
    except ClientError as e:
        logger.error("Помилка при отриманні списку EC2: %s", e)
        raise

    if not instance_ids:
        logger.info("Не знайдено запущених інстансів із тегом %s=%s.", tag_key, tag_value)
        return {"status": "no_action", "stopped_instances": []}

    logger.info("Знайдено цільові інстанси для зупинки: %s", instance_ids)

    try:
        ec2.stop_instances(InstanceIds=instance_ids, DryRun=dry_run)
        logger.info("Успішно ініційовано зупинку інстансів: %s", instance_ids)
        return {"status": "stopped", "stopped_instances": instance_ids}
    except ClientError as e:
        error_code = e.response["Error"]["Code"]
        if error_code == "DryRunOperation":
            logger.info("[DRY_RUN] Перевірка прав успішна. Інстанси НЕ зупинено: %s", instance_ids)
            return {"status": "dry_run_success", "target_instances": instance_ids}
        logger.error("Критична помилка при зупинці інстансів (%s): %s", error_code, e)
        raise


if __name__ == "__main__":
    # Точка входу для локального тестування в WSL2
    result = lambda_handler({}, None)
    logger.info("Результат виконання: %s", result)