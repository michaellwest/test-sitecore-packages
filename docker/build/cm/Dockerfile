# escape=`

ARG BASE_IMAGE
ARG TOOLING_IMAGE

FROM ${TOOLING_IMAGE} as tooling
FROM ${BASE_IMAGE}


SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Install IISRewrite Module https://www.iis.net/downloads/microsoft/url-rewrite
#RUN Invoke-WebRequest -Uri https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi -OutFile c:/inetpub/rewrite_amd64_en-US.msi
# In some corporate networks using ADD might be better.
ADD https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi c:/inetpub/rewrite_amd64_en-US.msi
RUN powershell -Command Start-Process -FilePath c:/inetpub/rewrite_amd64_en-US.msi -ArgumentList "/qn" -Wait; Remove-Item -Path c:/inetpub/rewrite_amd64_en-US.msi;

# Copy development tools and entrypoint
COPY --from=tooling \tools\ \tools\

WORKDIR C:\inetpub\wwwroot

# Copy role transforms
COPY .\transforms\ \transforms\role\

# Perform role transforms
RUN C:\tools\scripts\Invoke-XdtTransform.ps1 -Path .\ -XdtPath C:\transforms\role