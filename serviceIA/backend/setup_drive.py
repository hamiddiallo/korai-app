#!/usr/bin/env python3
"""Script unique pour obtenir votre refresh token Google Drive
À exécuter UNE SEULE FOIS après avoir téléchargé client_secret.json
"""

import os
from google_auth_oauthlib.flow import InstalledAppFlow

SCOPES = ['https://www.googleapis.com/auth/drive.file']

def get_refresh_token():
    CLIENT_SECRET_FILE = 'client_secret.json'
    
    if not os.path.exists(CLIENT_SECRET_FILE):
        print("❌ Fichier client_secret.json introuvable!")
        print("\n📋 Instructions :")
        print("  1. Placez le fichier JSON téléchargé dans ce dossier")
        print("  2. Renommez-le en 'client_secret.json'")
        return
    
    print("🔐 Lancement de l'authentification Google...")
    print("➡️ Une fenêtre de navigateur va s'ouvrir")
    print("➡️ Connectez-vous avec votre compte Google personnel")
    print("➡️ Acceptez les permissions demandées\n")
    
    flow = InstalledAppFlow.from_client_secrets_file(CLIENT_SECRET_FILE, SCOPES)
    
    credentials = flow.run_local_server(
        port=0,
        access_type='offline',
        prompt='consent'
    )
    
    print("\n" + "="*70)
    print("✅ AUTHENTIFICATION RÉUSSIE !")
    print("="*70)
    print("\n📋 COPIEZ CES VALEURS DANS VOTRE FICHIER .env :")
    print("-"*70)
    print(f"GOOGLE_REFRESH_TOKEN={credentials.refresh_token}")
    print(f"GOOGLE_CLIENT_ID={credentials.client_id}")
    print(f"GOOGLE_CLIENT_SECRET={credentials.client_secret}")
    print("-"*70)
    
    # Sauvegarder dans .env
    env_path = '.env'
    env_content = ""
    
    if os.path.exists(env_path):
        with open(env_path, 'r') as f:
            env_content = f.read()
    
    updates = {
        'GOOGLE_REFRESH_TOKEN': credentials.refresh_token,
        'GOOGLE_CLIENT_ID': credentials.client_id,
        'GOOGLE_CLIENT_SECRET': credentials.client_secret,
        'GOOGLE_DRIVE_ENABLED': 'true'
    }
    
    for key, value in updates.items():
        if value:
            if key in env_content:
                lines = env_content.split('\n')
                for i, line in enumerate(lines):
                    if line.startswith(f'{key}='):
                        lines[i] = f'{key}={value}'
                env_content = '\n'.join(lines)
            else:
                env_content += f'\n{key}={value}' if env_content else f'{key}={value}'
    
    with open(env_path, 'w') as f:
        f.write(env_content.strip())
    
    print(f"\n✅ Variables sauvegardées dans {env_path}")
    print("\n🎯 Vous pouvez maintenant utiliser votre backend avec Google Drive !")

if __name__ == "__main__":
    get_refresh_token()