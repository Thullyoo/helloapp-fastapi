# Automatização de Aplicação com GitHub Actions e ArgoCD

Este projeto demonstra como configurar a automação de uma aplicação utilizando **GitHub Actions** para CI/CD e **ArgoCD** para implantação contínua via GitOps em um ambiente Kubernetes local. O objetivo é fornecer um fluxo de trabalho eficiente para gerenciar implantações de forma automatizada e escalável.

## 📋 Requisitos

- **Rancher Desktop**: Para executar um cluster Kubernetes localmente.
- **ArgoCD**: Para gerenciar implantações via GitOps.

## 🛠️ Passo a Passo para Configuração

Siga os passos abaixo para configurar e implantar a aplicação com sucesso:

### 1. Configurar o Ambiente Kubernetes com Rancher Desktop

1. **Instale o Rancher Desktop**:
   - Baixe e instale o [Rancher Desktop](https://rancherdesktop.io/) para sua plataforma (Windows, macOS ou Linux).
   - Inicie o Rancher Desktop e certifique-se de que o Kubernetes está ativo.

2. **Verifique o Kubernetes**:
   - Execute o comando abaixo para confirmar que o cluster está funcionando:
     ```bash
     kubectl cluster-info
     ```

### 2. Instalar e Configurar o ArgoCD no Kubernetes Local ⚙️

O **ArgoCD** será utilizado para gerenciar implantações via GitOps. Siga os passos abaixo para instalá-lo:

1. **Crie o namespace do ArgoCD**:
   ```bash
   kubectl create namespace argocd
   ```

2. **Instale o ArgoCD**:
   - Aplique o manifesto oficial do ArgoCD:
     ```bash
     kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
     ```

3. **Configure o serviço do ArgoCD para acesso externo**:
   - Altere o tipo de serviço do `argocd-server` para `LoadBalancer`:
     ```bash
     kubectl edit svc argocd-server -n argocd
     ```
   - No editor, modifique a propriedade `spec.type` de `ClusterIP` para `LoadBalancer`:
     ```yaml
     spec:
       type: LoadBalancer
     ```

4. **Acesse a interface gráfica do ArgoCD**:
   - Execute o comando de port-forward para acessar a interface:
     ```bash
     kubectl port-forward svc/argocd-server -n argocd 8080:443
     ```
   - Mantenha o terminal aberto durante o uso.
   - Acesse a interface em [https://localhost:8080](https://localhost:8080).

   ![Tela de login do ArgoCD](/assets/images/img1.png)

5. **Obtenha as credenciais de login**:
   - **Usuário**: `admin`
   - **Senha**: Recupere a senha no Windows com o comando:
     ```powershell
     kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | ForEach-Object { [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($_)) }
     ```
   - Copie o output do comando e use-o como senha na interface do ArgoCD.
