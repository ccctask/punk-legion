FROM debian:bookworm-slim
ARG GODOT_VERSION=4.6.1
RUN apt-get update && apt-get install -y --no-install-recommends ca-certificates curl unzip libfontconfig1 libx11-6 libxcursor1 libxi6 libxinerama1 libxrandr2 libgl1 libasound2 libxkbcommon0 && rm -rf /var/lib/apt/lists/*
RUN set -eux; file="Godot_v${GODOT_VERSION}-stable_linux.x86_64"; base="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable"; cd /tmp; curl -fsSLO "$base/$file.zip"; curl -fsSLO "$base/SHA512-SUMS.txt"; grep -F "$file.zip" SHA512-SUMS.txt | sha512sum -c -; unzip "$file.zip"; install -m 755 "$file" /usr/local/bin/godot; rm "$file" "$file.zip" SHA512-SUMS.txt
WORKDIR /opt/room
COPY game/net/ ./net/
COPY game/battle/field.gd game/battle/simulation.gd game/battle/path_motion.gd ./battle/
COPY game/loadout/catalog.gd game/loadout/rules.gd ./loadout/
COPY game/expedition/rail_sites.gd ./expedition/
COPY deploy/server.godot ./project.godot
RUN install -d -o nobody -g nogroup -m 700 /var/lib/punk-room
USER nobody
ENV HOME=/tmp
EXPOSE 24567/udp
ENTRYPOINT ["godot", "--headless", "--path", "/opt/room", "--", "--server"]

