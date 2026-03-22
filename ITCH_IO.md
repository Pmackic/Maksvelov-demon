# Itch.io Export

Najjednostavniji put za ovaj projekat je `Web` export iz Godot editora.

## 1. Napravi Web export preset

U Godot editoru:

1. `Project -> Export`
2. `Add... -> Web`
3. Sačuvaj export u folder, na primer:

```text
build/web/
```

Posle exporta očekuj fajlove ovog tipa:

```text
build/web/index.html
build/web/*.js
build/web/*.wasm
build/web/*.pck
```

## 2. Zipuj ceo Web build

Itch.io za browser igru očekuje `.zip`.

Ako na svojoj mašini imaš `zip`, iz root-a projekta:

```bash
cd build/web
zip -r ../../maxwells-demon-web.zip .
```

Ako nemaš `zip`, instaliraj ga lokalno ili zipuj taj folder iz file manager-a.

Napomena:
- U ovom sandbox okruženju trenutno nije dostupan `zip`, samo `tar`, a to nije idealan format za itch HTML upload.

## 3. Upload na itch.io

Na itch.io:

1. `Create new project`
2. Upload `maxwells-demon-web.zip`
3. Obeleži:
   - `This file will be played in the browser`
4. Platform:
   - `HTML`
5. Preporuka za embed:
   - portrait or responsive layout

## 4. Preporučeni metapodaci

Predlog:

- Title: `Maxwell's Demon`
- Short description:
  `Mobilna 2D demonstracija Maxwellovog demona sa gasom, kapijom i prikazom Shannonove neuređenosti gasa.`

## 5. Šta proveriti pre upload-a

Pre nego što zipuješ:

1. igra se otvara bez error-a
2. UI ostaje čitljiv u portrait prikazu
3. kapija reaguje na touch/click hold
4. `Sandbox` radi bez dodatnih asset-a
5. AI demon je opcion i podrazumevano ne mora biti uključen

## 6. Opcioni dodatni build

Ako hoćeš i mobilni download uz browser verziju:

1. napravi i `Android` export
2. uploaduj `.apk` kao dodatni file na istoj itch stranici

To je koristan dodatak, ali za najbrži javni showcase `Web` build je glavni put.
