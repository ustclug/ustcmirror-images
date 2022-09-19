# Ref: https://github.com/tuna/tunasync-scripts/tree/master/dockerfiles/julia
FROM ustcmirror/base:alpine

ENV JULIA_DEPOT_PATH="/opt/julia/depot"
RUN apk update && apk add --no-cache curl python3 gnupg && \
        pip3 install jill && jill install 1.5 --confirm && \
        ln -s /opt/julias/julia-1.5 /opt/julia && \
        julia -e 'using Pkg; pkg"add StorageMirrorServer@0.2.1"' && \
        chmod a+rx -R $JULIA_DEPOT_PATH

ADD startup.jl /opt/julia/etc/julia/startup.jl
ADD ["pre-sync.sh", "sync.sh", "/"]
