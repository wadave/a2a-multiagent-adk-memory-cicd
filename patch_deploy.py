import yaml

with open('.github/workflows/deploy.yml', 'r') as f:
    data = f.read()

# I am going to dynamically insert the state rm step
insert_idx = data.find('      - name: Terraform Apply')

if insert_idx != -1:
    new_data = data[:insert_idx] + """      - name: Terraform State RM GitHub Resources
        working-directory: deployment/terraform
        run: |
          terraform state rm 'github_repository_environment.staging' || true
          terraform state rm 'github_repository_environment.main' || true
          terraform state rm 'github_actions_environment_variable.ge_app_staging' || true
          terraform state rm 'github_actions_environment_variable.ge_app_prod' || true
          terraform state rm 'github_actions_environment_variable.oauth_client_id_secret_name' || true

""" + data[insert_idx:]
else:
    new_data = data

with open('.github/workflows/deploy.yml', 'w') as f:
    f.write(new_data)
