
module "europa_network" {
  source                 = "../modules/network"
  epoch_id               = var.epoch_id
  active_color           = var.active_color
  active_honeytoken_trap = var.active_honeytoken_trap
  europa_active_topology = var.europa_active_topology
}

module "europa_identity" {
  source                    = "../modules/identity"
  epoch_id                  = var.epoch_id
  quarantine_honeybucket    = var.quarantine_honeybucket
  ephemeral_pipeline_policy = var.ephemeral_pipeline_policy
}

