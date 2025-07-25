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

Aqui está a versão revisada e aprimorada da seção solicitada do README, com uma explicação clara do que cada código faz, linguagem mais fluida, estrutura organizada e passos otimizados para maior clareza. As seções foram renumeradas para manter a consistência (de 3, 4, 6, 7 para 3, 4, 5, 6), e o conteúdo foi ajustado para ser mais conciso e informativo.



### 3. Criar o Dockerfile da Aplicação

O Dockerfile define a construção da imagem Docker para a aplicação, que utiliza **FastAPI** com **Uvicorn** em Python. A imagem será usada para implantar a aplicação no Kubernetes via ArgoCD.

**Dockerfile**:
```dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY main.py .

RUN pip install fastapi uvicorn

EXPOSE 5000

CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5000"]
```

**Explicação do Dockerfile**:
- `FROM python:3.11-slim`: Usa uma imagem base leve do Python 3.11 para reduzir o tamanho da imagem.
- `WORKDIR /app`: Define o diretório de trabalho como `/app` dentro do contêiner.
- `COPY main.py .`: Copia o arquivo `main.py` (que contém a aplicação FastAPI) para o diretório de trabalho.
- `RUN pip install fastapi uvicorn`: Instala as dependências necessárias (`fastapi` e `uvicorn`).
- `EXPOSE 5000`: Expõe a porta 5000, onde o Uvicorn servirá a aplicação.
- `CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "5000"]`: Inicia o servidor Uvicorn, executando o aplicativo FastAPI definido em `main.py` na porta 5000, acessível externamente.

### 4. Criar o Workflow do GitHub Actions

O workflow do GitHub Actions automatiza a construção, o push da imagem Docker e a atualização dos manifests Kubernetes em outro repositório. O arquivo é criado em `.github/workflows/docker-build-push-pr.yml`.

**Workflow**:
```yaml
name: Build Docker and PR to Update Manifest

on:
  workflow_dispatch:

permissions:
  contents: write

jobs:
  deploy:
    runs-on: ubuntu-latest

    steps:
      - name: Checkout Repository
        uses: actions/checkout@v3
        with:
          fetch-depth: 0

      - name: Configure Git
        run: |
          git config user.name "github-actions"
          git config user.email "github-actions@github.com"

      - name: Generate New Tag
        id: tagger
        run: |
          latest=$(git tag | grep '^v[0-9]\+$' | sort -V | tail -n1)
          next=$([ -z "$latest" ] && echo "v1" || echo "v$(( ${latest#v} + 1 ))")
          echo "Nova tag: $next"
          git tag "$next"
          git push origin "$next"
          echo "tag=$next" >> $GITHUB_OUTPUT

      - name: Log in to Docker Hub
        uses: docker/login-action@v2
        with:
          username: ${{ secrets.DOCKERHUB_USERNAME }}
          password: ${{ secrets.DOCKERHUB_TOKEN }}

      - name: Build and Push Docker Image
        uses: docker/build-push-action@v3
        with:
          context: .
          file: ./Dockerfile
          push: true
          tags: thullyodev/myapp-fastapi:${{ steps.tagger.outputs.tag }}

      - name: Configure SSH
        uses: webfactory/ssh-agent@v0.9.1
        with:
          ssh-private-key: ${{ secrets.SSH_PRIVATE_KEY }}

      - name: Update Manifests Repository
        run: |
          git clone git@github.com:Thullyoo/helloapp-manifests.git
          cd helloapp-manifests
          git config user.name "github-actions"
          git config user.email "github-actions@github.com"
          BRANCH_NAME=update-image-${{ steps.tagger.outputs.tag }}
          git checkout -b $BRANCH_NAME
          sed -i "s|image:.*|image: thullyodev/myapp-fastapi:${{ steps.tagger.outputs.tag }}|" k8s/deployment.yaml
          git add .
          git commit -m "chore: update image to ${{ steps.tagger.outputs.tag }}"
          git push origin $BRANCH_NAME

      - name: Create Pull Request
        run: |
          curl -X POST -H "Authorization: token ${{ secrets.PERSONAL_ACCESS_TOKEN }}" \
               -H "Accept: application/vnd.github.v3+json" \
               https://api.github.com/repos/Thullyoo/helloapp-manifests/pulls \
               -d "{\"title\":\"feat: update docker image to thullyodev/myapp-fastapi:${{ steps.tagger.outputs.tag }}\",\"head\":\"update-image-${{ steps.tagger.outputs.tag }}\",\"base\":\"main\",\"body\":\"This PR updates the Kubernetes manifests to use the new image: thullyodev/myapp-fastapi:${{ steps.tagger.outputs.tag }}\"}"
```

**Explicação do Workflow**:
- **Trigger**: O workflow é acionado manualmente via `workflow_dispatch`.
- **Permissões**: Concede permissão de escrita no repositório (`contents: write`).
- **Passos**:
  1. **Checkout Repository**: Clona o repositório com histórico completo (`fetch-depth: 0`).
  2. **Configure Git**: Define o usuário e e-mail do Git para commits automatizados.
  3. **Generate New Tag**: Gera uma nova tag incremental (ex.: `v1`, `v2`) com base na última tag existente.
  4. **Log in to Docker Hub**: Autentica no Docker Hub usando segredos (`DOCKERHUB_USERNAME` e `DOCKERHUB_TOKEN`).
  5. **Build and Push Docker Image**: Constrói e faz push da imagem Docker para o repositório `thullyodev/myapp-fastapi` com a nova tag.
  6. **Configure SSH**: Configura a chave SSH para acesso ao repositório de manifests.
  7. **Update Manifests Repository**: Clona o repositório `helloapp-manifests`, cria uma nova branch, atualiza o arquivo `k8s/deployment.yaml` com a nova tag da imagem e faz push.
  8. **Create Pull Request**: Cria um pull request no repositório de manifests para atualizar a imagem usada no deployment.

### 5. Criar o Manifesto Kubernetes para o ArgoCD

O manifesto Kubernetes define como a aplicação será implantada no cluster. Ele é armazenado no repositório `https://github.com/Thullyoo/helloapp-manifests`, na pasta `k8s`, no arquivo `deployment.yaml`.

**Manifesto**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-deployment
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp-fastapi
  template:
    metadata:
      labels:
        app: myapp-fastapi
    spec:
      containers:
      - name: fastapi-app
        image: thullyodev/myapp-fastapi:v5
        ports:
        - containerPort: 5000
```

**Explicação do Manifesto**:
- `apiVersion` e `kind`: Define um `Deployment` da API do Kubernetes.
- `metadata`: Nomeia o deployment como `myapp-deployment` no namespace `default`.
- `spec.replicas`: Especifica 2 réplicas do pod para alta disponibilidade.
- `spec.selector` e `template.metadata.labels`: Associa o deployment aos pods com o rótulo `app: myapp-fastapi`.
- `spec.template.spec.containers`: Define um contêiner chamado `fastapi-app` que usa a imagem Docker `thullyodev/myapp-fastapi:v5` e expõe a porta 5000.

### 6. Configurar as Variáveis de Ambiente

As variáveis de ambiente e segredos são configurados nos repositórios do GitHub para autenticar e automatizar o pipeline.

**Configurações**:
1. **Docker Hub**:
   - No repositório da aplicação, adicione os segredos:
     - `DOCKERHUB_USERNAME`: Nome de usuário do Docker Hub.
     - `DOCKERHUB_TOKEN`: Token de acesso do Docker Hub.
   - Acesse **Settings > Secrets and variables > Actions** no repositório para adicionar.

2. **Chaves SSH**:
   - Gere um par de chaves SSH (`ssh-keygen -t rsa`).
   - Adicione a chave pública como **Deploy Key** no repositório `helloapp-manifests` com permissão de escrita.
   - Adicione a chave privada como segredo (`SSH_PRIVATE_KEY`) no repositório da aplicação.

3. **GitHub Personal Access Token**:
   - Crie um token de acesso no GitHub com permissões de escrita/leitura no repositório `helloapp-manifests`.
   - Adicione o token como segredo (`PERSONAL_ACCESS_TOKEN`) no repositório da aplicação.

**Exemplo de Configuração**:
- Configuração de segredos no repositório da aplicação:
  ![Variáveis de ambiente](/assets/images/img17.png)
- Configuração de deploy key no repositório de manifests:
  ![Deploy key](/assets/images/img16.png)

**Explicação**:
- Os segredos garantem autenticação segura para o Docker Hub, acesso ao repositório de manifests via SSH e criação de pull requests via API do GitHub.
- A chave SSH permite que o workflow modifique o repositório `helloapp-manifests` sem expor credenciais diretamente.



### 7. Criar a Aplicação no ArgoCD

1. **Acesse o ArgoCD**: Faça login no ArgoCD com suas credenciais e clique em **Create Application** na interface.

   ![ArgoCD - Criar Aplicação](/assets/images/img2.png)

2. **Preencha os detalhes da aplicação**:
   - **Application Name**: Escolha um nome para a aplicação (ex.: `mywebapp`).
   - **Project Name**: Mantenha como `default`.
   - **Sync Policy**: Selecione **Automatic** para sincronização automática.
   - **Auto-create Namespace**: Habilite esta opção para criar automaticamente o namespace, se necessário.

   ![ArgoCD - Configuração da Aplicação](/assets/images/img3.png)

3. **Configure o repositório e o destino**:
   - **Repository URL**: Insira a URL do repositório que contém os manifestos (ex.: `https://github.com/seu-usuario/seu-repositorio`).
   - **Path**: Especifique o diretório onde os manifestos estão localizados, por exemplo, `k8s/`.
   - **Destination**:
     - **Cluster URL**: Use `https://kubernetes.default.svc` para o cluster padrão do Kubernetes.
     - **Namespace**: Defina o namespace desejado (ex.: `mywebapp`).

   ![ArgoCD - Configuração do Repositório](/assets/images/img4.png)

4. **Conclua a criação**:
   - Clique em **Create** para finalizar. A aplicação será criada e iniciará o processo de sincronização, exibindo uma tela com o status.

   ![ArgoCD - Sincronização em Andamento](/assets/images/img5.png)

5. **Verifique os recursos criados**:
   - Após a sincronização, execute o comando abaixo para listar os recursos criados pelo ArgoCD no namespace especificado:
     ```bash
     kubectl get all -n mywebapp
     ```
   - A saída mostrará os pods, serviços e outros recursos implantados.

   ![ArgoCD - Recursos Criados](/assets/images/img6.png)

6. **Acesse a aplicação**:
   - Selecione um dos pods listados e execute um port-forward para acessar a aplicação localmente:
     ```bash
     kubectl port-forward <nome-do-pod> 8080:80 -n mywebapp
     ```
   - Abra o navegador e acesse `http://localhost:8080` para verificar se a aplicação está funcionando corretamente.

   ![ArgoCD - Port-Forward](/assets/images/img7.png)

   ![ArgoCD - Aplicação em Execução](/assets/images/img8.png)

---

### 8. Teste de Automação

1. **Modifique o código da aplicação**:
   - Acesse o arquivo principal da aplicação (ex.: `main.py`) e altere a mensagem de saída, por exemplo, de `Olá, mundo` para `Hello, World!`.
   - Faça o commit e o push das alterações para o repositório:
     ```bash
     git commit -m "Alterar mensagem para Hello, World!"
     git push origin main
     ```

   ![Alteração no Código](/assets/images/img9.png)

2. **Execute o workflow no GitHub Actions**:
   - Acesse a aba **Actions** no repositório do GitHub e execute o workflow configurado para atualizar a imagem da aplicação.

   ![GitHub Actions - Workflow](/assets/images/img10.png)

3. **Verifique o Pull Request gerado**:
   - Após a execução do workflow, um Pull Request (PR) será automaticamente criado no repositório de manifestos, refletindo a atualização da imagem.

   ![PR Gerado](/assets/images/img11.png)
   ![Detalhes do PR](/assets/images/img12.png)

4. **Mescle o Pull Request**:
   - Revise o PR e clique em **Merge Pull Request** para aplicar as alterações no repositório de manifestos.

   ![Mesclagem do PR](/assets/images/img13.png)

5. **Aguarde a sincronização do ArgoCD**:
   - O ArgoCD detectará as alterações no repositório e sincronizará automaticamente a aplicação com a nova versão da imagem.

   ![ArgoCD - Sincronização Atualizada](/assets/images/img14.png)

6. **Verifique a aplicação atualizada**:
   - Execute novamente o comando de port-forward em um dos novos pods:
     ```bash
     kubectl port-forward <nome-do-pod> 8080:80 -n mywebapp
     ```
   - Acesse `http://localhost:8080` no navegador e confirme que a mensagem foi atualizada para `Hello, World!`.

   ![Aplicação Atualizada](/assets/images/img15.png)

7. **Confirme a nova imagem no Docker Hub**:
   - Acesse o Docker Hub e verifique que a nova imagem com a tag atualizada foi publicada.

   ![Nova Imagem no Docker Hub](/assets/images/img18.png)



