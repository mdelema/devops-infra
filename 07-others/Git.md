## Pasos para Vincular GitHub con Visual Studio.

1️⃣ Ver si ya tenés una clave SSH en tu máquina
En tu terminal, ejecutá:

    ls -al ~/.ssh

Si ves algo como id_rsa y id_rsa.pub o id_ed25519 y id_ed25519.pub, significa que ya tenés una.

2️⃣ Si no tenés clave, generá una nueva

    ssh-keygen -t ed25519 -C "tu-email-de-github"

Te va a preguntar dónde guardar la clave (enter para la ruta por defecto)

Podés dejar passphrase vacío (o poner uno si querés más seguridad)

3️⃣ Agregar la clave al agente SSH
    
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/id_ed25519

4️⃣ Agregar la clave a tu GitHub
Mostramos la clave pública:

    cat ~/.ssh/id_ed25519.pub       

Copiá la salida completa y en GitHub vas a:    Settings → SSH and GPG keys → New SSH key
Pegás la clave, le ponés un nombre, guardás.

5️⃣ Probar la conexión

    ssh -T git@github.com

Si todo está bien, te va a decir algo como:

    Hi "user_name"! You've successfully authenticated...