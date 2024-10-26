resource "aws_kms_key" "primary" {
  description = "Key for DynamoDB primary region"
}

resource "aws_dynamodb_table" "this" {

  name           = var.name
  billing_mode   = var.billing_mode
  hash_key       = var.hash_key
  read_capacity  = var.read_capacity
  write_capacity = var.write_capacity
  table_class    = var.table_class


  dynamic "attribute" {
    for_each = var.attributes

    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }



  server_side_encryption {
    enabled     = var.server_side_encryption_enabled
    kms_key_arn = aws_kms_key.primary.arn
  }

  tags = merge(
    var.tags,
    {
      "Name" = format("%s", var.name)
    },
  )

  timeouts {
    create = lookup(var.timeouts, "create", null)
    delete = lookup(var.timeouts, "delete", null)
    update = lookup(var.timeouts, "update", null)
  }
}