# README.md contents
# My Application Helm Chart

This Helm chart packages a complete application consisting of a frontend, backend, and MySQL database, along with all necessary Kubernetes resources.

## Directory Structure

- `charts/`: Contains any sub-charts used in the application.
- `templates/`: Contains the Kubernetes resource templates.
  - `backend-deployment.yaml`: Deployment resource for the backend application.
  - `backend-service.yaml`: Service resource for the backend application.
  - `frontend-deployment.yaml`: Deployment resource for the frontend application.
  - `frontend-service.yaml`: Service resource for the frontend application.
  - `mysql-secret.yaml`: Secret resource for storing sensitive information.
  - `mysql-statefulset.yaml`: StatefulSet resource for the MySQL database.
  - `mysql-service.yaml`: Service resource for the MySQL database.
  - `pv-pvc.yaml`: PersistentVolume and PersistentVolumeClaim resources for MySQL.
  - `_helpers.tpl`: Helper templates for reuse across other templates.
- `Chart.yaml`: Metadata about the Helm chart.
- `values.yaml`: Default configuration values for the Helm chart.

## Installation

To install the chart, use the following command:

```
helm install my-application ./my-application
```

## Configuration

You can customize the deployment by modifying the `values.yaml` file. This file contains default values that can be overridden.

## Uninstallation

To uninstall the chart, use the following command:

```
helm uninstall my-application
```

## License

This project is licensed under the MIT License.

## Environment Variables

The following environment variables are required to deploy the chart:

- `MYSQL_ROOT_PASSWORD`: The root password for MySQL.
- `MYSQL_USER`: The MySQL user.
- `MYSQL_PASSWORD`: The password for the MySQL user.

## Installation

To install the chart with the release name `myapp`:

```sh
export MYSQL_ROOT_PASSWORD=your-root-password
export MYSQL_USER=your-mysql-user
export MYSQL_PASSWORD=your-mysql-password

helm install myapp ./my-application