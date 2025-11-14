# Use uma imagem base do Python
FROM python:3.10-slim

# Defina o diretório de trabalho dentro do container
WORKDIR /app

# Copie os arquivos de requisitos para o container
COPY ../requirements.txt .

# Instale as dependências do projeto
RUN pip install --no-cache-dir -r requirements.txt

# Copie o restante do código da aplicação para o container
COPY .. .

# Exponha a porta em que o Flask será executado
EXPOSE 5000

# Comando para iniciar a aplicação
CMD ["python", "app.py"]
