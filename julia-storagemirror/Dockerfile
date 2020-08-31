FROM ustcmirror/base:alpine-3.11
# Ref: https://github.com/tuna/tunasync-scripts/tree/master/dockerfiles/julia
RUN apk update && apk add --no-cache python3 gnupg && \
        pip3 install jill && jill install 1.5 --confirm && \
        ln -s /opt/julias/julia-1.5 /opt/julia
ENV JULIA_DEPOT_PATH="/opt/julia/depot"
RUN julia -e 'using Pkg; pkg"add StorageMirrorServer@0.1.6"' && \
        chmod a+rx -R $JULIA_DEPOT_PATH
ADD startup.jl /opt/julia/etc/julia/startup.jl
ADD sync.sh /
