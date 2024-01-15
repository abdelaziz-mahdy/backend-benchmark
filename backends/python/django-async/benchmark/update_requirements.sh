cd "${0%/*}"



poetry lock && poetry install --no-root && poetry update 
