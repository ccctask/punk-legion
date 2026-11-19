FROM python:3.13-alpine
WORKDIR /app
COPY config ./config
COPY world_calendar.py onboarding.py camp.py storefront.py friends.py ./
COPY party.py pump.py factory.py armory.py ./
COPY treasure.py treasure_combat.py ./
RUN mkdir -p /run/solo-missions && chown 65534:65534 /run/solo-missions && chmod 700 /run/solo-missions
RUN mkdir -p /run/camp && chown 65534:65534 /run/camp && chmod 700 /run/camp
COPY private_base.py platforms.py ./
COPY production.py plaques.py ./
COPY expedition.py ./
COPY service_record.py favorites.py ./
COPY recovery.py ./
COPY raids.py ./
COPY server.py profile_maintenance.py account_access.py operations.py inventory.py workshop.py workshop_catalog.json ./
CMD ["python","-u","server.py","serve","--bind","0.0.0.0"]

