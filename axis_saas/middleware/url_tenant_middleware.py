from django.db import connection
from django_tenants.middleware import TenantMainMiddleware
from django_tenants.utils import get_tenant_model
from django.urls import resolve

class URLPathTenantMiddleware(TenantMainMiddleware):
    """
    Custom tenant middleware: extract schema_name from URL path,
    set request.tenant, and switch the database connection to that schema.
    """
    def __call__(self, request):
        # For non‑portal paths, stay on public schema
        if not request.path_info.startswith('/portal/'):
            request.tenant = None
            connection.set_schema_to_public()
            return self.get_response(request)

        # Extract schema_name from /portal/<schema_name>/...
        parts = request.path_info.strip('/').split('/')
        if len(parts) >= 2 and parts[0] == 'portal':
            schema_name = parts[1]
        else:
            # Malformed path, stay on public
            request.tenant = None
            connection.set_schema_to_public()
            return self.get_response(request)

        TenantModel = get_tenant_model()
        try:
            # Query the tenant record from the public schema (default connection)
            tenant = TenantModel.objects.get(schema_name=schema_name)
            request.tenant = tenant
            connection.set_tenant(request.tenant)
        except TenantModel.DoesNotExist:
            # No SchoolClient row – we will let the view create it
            # but still keep connection on public schema
            request.tenant = None
            request.missing_tenant_schema = schema_name
            connection.set_schema_to_public()

        return self.get_response(request)
