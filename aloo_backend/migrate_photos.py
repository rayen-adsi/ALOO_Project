import sys
import os
import re

# Add the aloo_backend directory to the path so we can import app
sys.path.append(os.path.dirname(os.path.abspath(__file__)))

from app import app, db, Client, Provider
import json

def strip_url(field_value):
    if not field_value:
        return None
    # If it's a JSON string (like portfolio), handle it
    if isinstance(field_value, str) and (field_value.startswith("[") or field_value.startswith("{")):
        try:
            items = json.loads(field_value)
            if isinstance(items, list):
                return json.dumps([strip_url(i) for i in items])
        except:
            pass
    
    # Standard URL stripping
    if isinstance(field_value, str) and field_value.startswith("http"):
        # Extract filename from end of URL
        return field_value.split("/")[-1]
    
    return field_value

def migrate():
    with app.app_context():
        print("Starting photo migration...")
        
        # 1. Update Clients
        clients = Client.query.all()
        for c in clients:
            if c.profile_photo:
                new_val = strip_url(c.profile_photo)
                if new_val != c.profile_photo:
                    print(f"Migrating Client {c.id} profile photo: {c.profile_photo} -> {new_val}")
                    c.profile_photo = new_val
        
        # 2. Update Providers
        providers = Provider.query.all()
        for p in providers:
            # Profile Photo
            if p.profile_photo:
                new_val = strip_url(p.profile_photo)
                if new_val != p.profile_photo:
                    print(f"Migrating Provider {p.id} profile photo: {p.profile_photo} -> {new_val}")
                    p.profile_photo = new_val
            
            # Portfolio (Stored as JSON string in DB)
            if p.portfolio:
                new_val = strip_url(p.portfolio)
                if new_val != p.portfolio:
                    print(f"Migrating Provider {p.id} portfolio")
                    p.portfolio = new_val
        
        db.session.commit()
        print("Migration complete!")

if __name__ == "__main__":
    migrate()
