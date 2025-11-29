# escape=`

ARG BASE_IMAGE
ARG TOOLING_IMAGE
ARG MANAGEMENT_SERVICES_IMAGE
ARG SPE_IMAGE
ARG SXA_IMAGE

FROM ${SXA_IMAGE} as sxa
FROM ${SPE_IMAGE} as spe
FROM ${MANAGEMENT_SERVICES_IMAGE} as management_services
FROM ${TOOLING_IMAGE} as tooling
FROM ${BASE_IMAGE}

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Install IISRewrite Module https://www.iis.net/downloads/microsoft/url-rewrite
#RUN Invoke-WebRequest -Uri https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi -OutFile c:/inetpub/rewrite_amd64_en-US.msi
# In some corporate networks using ADD might be better.
ADD https://download.microsoft.com/download/1/2/8/128E2E22-C1B9-44A4-BE2A-5859ED1D4592/rewrite_amd64_en-US.msi c:/inetpub/rewrite_amd64_en-US.msi
RUN powershell -Command Start-Process -FilePath c:/inetpub/rewrite_amd64_en-US.msi -ArgumentList "/qn" -Wait; Remove-Item -Path c:/inetpub/rewrite_amd64_en-US.msi;

COPY --from=tooling \tools\ \tools\
COPY \tools\ \tools\

WORKDIR /inetpub/wwwroot
COPY --from=management_services \module\cm\content .\
COPY --from=spe \module\cm\content .\
COPY --from=sxa \module\cm\content .\
COPY --from=sxa \module\tools \module\tools
RUN C:\module\tools\Initialize-Content.ps1 -TargetPath .\; `
    Remove-Item -Path C:\module -Recurse -Force;

COPY .\content .\

# TODO: What about transorms