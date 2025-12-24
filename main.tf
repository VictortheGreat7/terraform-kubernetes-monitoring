resource "kubernetes_namespace_v1" "namespace" {
  count = var.create_namespace ? 1 : 0
  metadata {
    annotations = {
      name = var.namespace
    }
    name = var.namespace
  }
}

resource "kubernetes_config_map_v1" "grafana_additional_dashboards" {
  metadata {
    name      = "grafana-additional-dashboards"
    namespace = var.create_namespace ? kubernetes_namespace_v1.namespace[0].id : var.namespace
    labels = {
      "grafana_dashboard" = "1"
    }
  }
  data = {
    "grafana-dashboard-node-exporter.json"    = file("${path.module}/templates/grafana-dashboard-node-exporter.json")
    "grafana-dashboard-node-exporter_en.json" = file("${path.module}/templates/grafana-dashboard-node-exporter-en.json")
    "grafana-dashboard-nginx-controller.json" = file("${path.module}/templates/grafana-dashboard-nginx-controller.json")
  }
}

resource "kubernetes_config_map_v1" "grafana_additional_datasource" {
  count = var.loki_url != null ? 1 : 0

  metadata {
    name      = "grafana-additional-datasource"
    namespace = var.create_namespace ? kubernetes_namespace_v1.namespace[0].id : var.namespace
    labels = {
      "grafana_datasource" = "1"
    }
  }
  data = {
    "grafana-loki-stack-datasource.yaml" = templatefile("${path.module}/templates/grafana-loki-datasource.yaml",
      {
        LOKI_URL = var.loki_url
      }
    )
  }
}

resource "kubernetes_secret_v1" "grafana_ldap_toml" {
  metadata {
    name      = "prometheus-operator-grafana-ldap-toml"
    namespace = var.create_namespace ? kubernetes_namespace_v1.namespace[0].id : var.namespace
  }

  data = {
    ldap-toml = local.grafana_ldap_toml
  }
}

resource "helm_release" "prometheus-operator" {
  name            = local.prometheus_chart
  repository      = local.prometheus_repository
  chart           = local.prometheus_chart
  namespace       = var.create_namespace ? kubernetes_namespace_v1.namespace[0].id : var.namespace
  cleanup_on_fail = true
  version         = var.prometheus_chart_version

  # Set grafana.ini with ldap_auth or your custom values
  values = concat(local.grafana_ldap_auth, var.additional_values)

  # Disable unused metrics
  set = [
    {
      name  = "kubeEtcd.enabled"
      value = "false"
    },
    {
      name  = "kubeControllerManager.enabled"
      value = "false"
    },
    {
      name  = "kubeScheduler.enabled"
      value = "false"
    },
    {
      name  = "alertmanager.ingress.enabled"
      value = "true"
    },
    {
      name  = "alertmanager.ingress.pathType"
      value = "ImplementationSpecific"
    },
    {
      name  = "alertmanager.ingress.hosts[0]"
      value = "${var.alertmanager_subdomain}${var.domain}"
    },
    {
      name  = "alertmanager.ingress.tls[0].hosts[0]"
      value = "${var.alertmanager_subdomain}${var.domain}"
    },
    {
      name  = "alertmanager.ingress.tls[0].secretName"
      value = var.alertmanager_tls == null ? var.tls : var.alertmanager_tls
    },
    {
      name  = "alertmanager.ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/whitelist-source-range"
      value = replace(var.alertmanager_whitelist == null ? var.cidr_whitelist : var.alertmanager_whitelist, ",", "\\,")
      type  = "string"
    },
    {
      name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.volumeName"
      value = kubernetes_persistent_volume_v1.alertmanager_pv.id
    },
    {
      name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.accessModes[0]"
      value = var.alertmanager_pv_access_modes
    },
    {
      name  = "alertmanager.alertmanagerSpec.storage.volumeClaimTemplate.spec.resources.requests.storage"
      value = kubernetes_persistent_volume_v1.alertmanager_pv.spec.0.capacity.storage
    },
    {
      name  = "prometheus.ingress.enabled"
      value = "true"
    },
    {
      name  = "prometheus.ingress.pathType"
      value = "ImplementationSpecific"
    },
    {
      name  = "prometheus.ingress.hosts[0]"
      value = "${var.prometheus_subdomain}${var.domain}"
    },
    {
      name  = "prometheus.ingress.tls[0].hosts[0]"
      value = "${var.prometheus_subdomain}${var.domain}"
    },
    {
      name  = "prometheus.ingress.tls[0].secretName"
      value = var.prometheus_tls == null ? var.tls : var.prometheus_tls
    },
    {
      name  = "prometheus.ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/whitelist-source-range"
      value = replace(var.prometheus_whitelist == null ? var.cidr_whitelist : var.prometheus_whitelist, ",", "\\,")
      type  = "string"
    },
    {
      name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.volumeName"
      value = kubernetes_persistent_volume_v1.prometheus_pv.id
    },
    {
      name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.accessModes[0]"
      value = var.prometheus_pv_access_modes
    },
    {
      name  = "prometheus.prometheusSpec.storageSpec.volumeClaimTemplate.spec.resources.requests.storage"
      value = kubernetes_persistent_volume_v1.prometheus_pv.spec.0.capacity.storage
    },
    {
      name  = "prometheus.prometheusSpec.retentionSize"
      value = var.prometheus_retentionSize == null ? "${kubernetes_persistent_volume_v1.prometheus_pv.spec.0.capacity.storage}B" : var.prometheus_retentionSize
    },
    {
      name  = "prometheus.prometheusSpec.retention"
      value = var.prometheus_retention
    },
    {
      name  = "grafana.ingress.enabled"
      value = "true"
    },
    {
      name  = "grafana.ingress.pathType"
      value = "ImplementationSpecific"
    },
    {
      name  = "grafana.ingress.hosts[0]"
      value = "${var.grafana_subdomain}${var.domain}"
    },
    {
      name  = "grafana.ingress.tls[0].hosts[0]"
      value = "${var.grafana_subdomain}${var.domain}"
    },
    {
      name  = "grafana.ingress.tls[0].secretName"
      value = var.grafana_tls == null ? var.tls : var.grafana_tls
    },
    {
      name  = "grafana.ingress.annotations.nginx\\.ingress\\.kubernetes\\.io/whitelist-source-range"
      value = replace(var.grafana_whitelist == null ? var.cidr_whitelist : var.grafana_whitelist, ",", "\\,")
      type  = "string"
    },
    {
      name  = "grafana.sidecar.dashboards.enabled"
      value = "true"
    },
    {
      name  = "grafana.adminPassword"
      value = var.grafana_admin_password
    },
    {
      name  = "grafana.ldap.enabled"
      value = var.grafana_ldap_enable
    },
    {
      name  = "grafana.ldap.existingSecret"
      value = kubernetes_secret_v1.grafana_ldap_toml.metadata[0].name
    },
    {
      name  = "grafana.persistence.enabled"
      value = "true"
    },
    {
      name  = "grafana.persistence.storageClassName"
      value = kubernetes_persistent_volume_v1.grafana_pv.spec.0.storage_class_name
    },
    {
      name  = "grafana.persistence.volumeName"
      value = kubernetes_persistent_volume_v1.grafana_pv.id
    },
    {
      name  = "grafana.persistence.accessModes[0]"
      value = var.grafana_pv_access_modes
    },
    {
      name  = "grafana.persistence.size"
      value = kubernetes_persistent_volume_v1.grafana_pv.spec.0.capacity.storage
    },
    {
      name  = "grafana.persistence.subPath"
      value = "grafana"
    }
  ]

  set_sensitive = [
    for set in var.additional_set : {
      name  = set.name
      value = set.value
      type  = lookup(set, "type", null)
    }
  ]

  depends_on = [
    kubernetes_persistent_volume_v1.prometheus_pv, kubernetes_persistent_volume_v1.alertmanager_pv,
    kubernetes_persistent_volume_v1.grafana_pv, kubernetes_config_map_v1.grafana_additional_dashboards
  ]
}
