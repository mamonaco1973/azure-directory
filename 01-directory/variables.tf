# ------------------------------------------------------------------------------
# Purpose:
#   Controls whether Azure Bastion infrastructure is deployed.
#
# Behavior:
#   - true  : Deploy Bastion subnet, NSG, public IP, and Bastion host.
#   - false : Skip Bastion-related resources entirely.
#
# Notes:
#   - Default is false to avoid unnecessary cost.
#   - When enabled, dependent resources must use count or for_each logic.
# ==============================================================================

variable "bastion_support" {
  description = "Deploy Azure Bastion resources"
  type        = bool
  default     = false
}
