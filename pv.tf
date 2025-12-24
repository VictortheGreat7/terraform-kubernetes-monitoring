resource "kubernetes_persistent_volume" "prometheus_pv" {
  metadata {
    name = var.prometheus_pv_name
  }
  spec {
    access_modes = [var.prometheus_pv_access_modes]
    capacity = {
      storage = var.prometheus_pv_size
    }
    storage_class_name               = var.prometheus_pv_storage_class_name
    persistent_volume_reclaim_policy = "Retain"

    dynamic "nfs" {
      for_each = var.prometheus_disk_type == "nfs" ? [1] : []
      content {
        path   = var.prometheus_disk_type == "nfs" && length(var.prometheus_disk_param) > 0 ? lookup(var.prometheus_disk_param[0], "path", var.nfs_path) : var.nfs_path
        server = var.prometheus_disk_type == "nfs" && length(var.prometheus_disk_param) > 0 ? lookup(var.prometheus_disk_param[0], "server", var.nfs_endpoint) : var.nfs_endpoint
      }
    }

    dynamic "aws_elastic_block_store" {
      for_each = var.prometheus_disk_type == "aws" ? [1] : []
      content {
        volume_id = var.prometheus_disk_param[0].volume_id
        read_only = lookup(var.prometheus_disk_param[0], "read_only", false)
        partition = lookup(var.prometheus_disk_param[0], "partition", null)
        fs_type   = lookup(var.prometheus_disk_param[0], "fs_type", null)
      }
    }

    dynamic "gce_persistent_disk" {
      for_each = var.prometheus_disk_type == "gce" ? [1] : []
      content {
        pd_name   = var.prometheus_disk_param[0].pd_name
        read_only = lookup(var.prometheus_disk_param[0], "read_only", false)
        partition = lookup(var.prometheus_disk_param[0], "partition", null)
        fs_type   = lookup(var.prometheus_disk_param[0], "fs_type", null)
      }
    }
  }
}
resource "kubernetes_persistent_volume" "alertmanager_pv" {
  metadata {
    name = var.alertmanager_pv_name
  }
  spec {
    access_modes = [var.alertmanager_pv_access_modes]
    capacity = {
      storage = var.alertmanager_pv_size
    }
    storage_class_name               = var.alertmanager_storage_class_name
    persistent_volume_reclaim_policy = "Retain"

    nfs {
      path   = var.nfs_path
      server = var.nfs_endpoint
    }
  }
}
resource "kubernetes_persistent_volume" "grafana_pv" {
  metadata {
    name = var.grafana_pv_name
  }
  spec {
    access_modes = [var.grafana_pv_access_modes]
    capacity = {
      storage = var.grafana_pv_size
    }
    storage_class_name               = var.grafana_storage_class_name
    persistent_volume_reclaim_policy = "Retain"

    nfs {
      path   = var.nfs_path
      server = var.nfs_endpoint
    }
  }
}