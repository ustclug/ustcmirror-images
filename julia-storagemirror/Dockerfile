FROM ustcmirror/base:alpine-3.11

RUN apk update && apk add --no-cache python3 gnupg && \
    pip3 install jill 
RUN jill install 1.5 --confirm && julia -e 'using Pkg; pkg"add StorageMirrorServer@0.1.6"'
ADD startup.jl /usr/local/julia/etc/julia/startup.jl
ADD sync.sh /
