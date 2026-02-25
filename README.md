# yz_druglab

**Druglab** – et FiveM-resource til at køre druglabs med indgang, kode, terminal og pakning. Lavet af **Yazoo**.

---

## Tak fordi du bruger mit script

Det betyder meget, at du har valgt **yz_druglab** til din server. Jeg har brugt tid på at lave noget, der er nemt at sætte op og bruge, og jeg håber det giver jer god RP og sjove øjeblikke i jeres druglab.

Hvis du er tilfreds, er det en kæmpe hjælp at:
- **Lade en review** eller feedback, hvis scriptet er købt/delt et sted
- **Rapportere bugs** eller forslag, så andre også kan få glæde af forbedringer
- **Være fair** – respektér at scriptet er lavet med omtanke, og del det ikke ulovligt

Tak for jeres tillid – og god fornøjelse med labbet.

— **Yazoo**

---

## Funktioner

- **Opret/køb druglabs** – Politiet kan oprette labs via kommando, spillere kan købe ved sælgerzone eller ved indgangen
- **Flere stoftyper** – Kokain, svampe, heroin, cannabis, amfetamin (konfigurerbart i `config.lua`)
- **Shell-interiører** – Forskellige indgangs- og lab-shells pr. stof (fx kokain-, meth-, weed-shells)
- **Kodeord** – 4-cifret kode ved indgang; kun ejer og medlemmer har adgang
- **Lab-terminal** – UI med produktion (start/pause/stop), lager (ox_inventory stash), medlemmer og kodeændring
- **Pakning** – Omdan poser til pakket stof ved pakkespotet i labbet (konfigurerbart antal og varer)
- **Discord-logs** – Valgfrie webhooks ved oprettelse og køb af labs
- **ESX** – Integreret med job (politi opretter), ejerskab og penge ved køb

---

## Krav

- **FiveM** server med **Lua 5.4**
- **es_extended** (ESX)
- **ox_lib**
- **ox_target**
- **ox_inventory**
- **oxmysql**

Hvis du bruger housing-shells (fx `shell_coke2`, `shell_meth`, `shell_weed2`), skal den ressource, der leverer disse modeller, være startet før **yz_druglab**.

---

## Installation

1. Kopiér mappen **yz_druglab** ind i din server `resources` (fx `resources/[yazoo]/yz_druglab`).
2. Tilføj i `server.cfg`:
   ```cfg
   ensure ox_lib
   ensure ox_target
   ensure ox_inventory
   ensure es_extended
   ensure oxmysql
   ensure yz_druglab
   ```
3. Kør evt. SQL fra `sql/` (tabeller oprettes også automatisk af scriptet ved første start).
4. Åbn **config.lua** og tilpas:
   - Hvem der må oprette labs (`Config.CreateLabRank`)
   - Stoftyper og bande-jobs
   - Lab-pris, sælgerzone, pakning, Discord-webhooks m.m.

---

## Konfiguration (overblik)

| Konfiguration | Beskrivelse |
|---------------|-------------|
| `Config.CreateLabRank` | Job + grade der må bruge `/opretdruglab` (fx politi grade 1) |
| `Config.GangJobs` | Jobs der kan købe labs (fx bander) |
| `Config.LabPrice` | Standardpris for at købe et nyt lab |
| `Config.LabSellerZone` | Zone hvor spillere kan købe et lab (coords, size, rotation) |
| `Config.DrugTypes` | Stoftyper (id + label) |
| `Config.ShellsByDrugType` | Indgangs- og lab-shells pr. stof |
| `Config.PackingByDrugType` | Hvilke items der skal pakkes og til hvad (antal, labels) |
| `Config.DiscordWebhookCreateLab` / `Config.DiscordWebhookBuyLab` | Discord-webhooks for oprettelse/køb |

Tænd **Config.Debug = true** kun under fejlsøgning.

---

## Kommandoser og brug

| Kommando | Beskrivelse |
|----------|-------------|
| `/opretdruglab` | Åbner menuen til at oprette et lab (kræver rettighed ift. `Config.CreateLabRank`) |
| `/druglabs` | Viser liste over labs (politi kan slette fra listen) |

**Spillere:**
- Gå til et lab-indgang (blip vises for ejere) → **Gå ind** (ox_target) → indtast kode på keypad.
- Inde i labbet: brug **terminalen** (laptop) til UI (produktion, lager, medlemmer, kode).
- Ved **pakkespotet**: [E] for at omdanne poser til pakket stof (antal og varer styres af config).
- **Forlad lab**: brug ox_target ved udgangen.

---

## Support og rettigheder

Scriptet er lavet af **Yazoo** 
Ved køb eller download følger de vilkår, du har modtaget det under. Misbrug eller ulovlig videre distribution er ikke tilladt.

Hvis du finder en fejl eller har et fornuftigt forslag, er det fedt med en besked – tak igen for at I bruger **yz_druglab**.

Join min discord her: https://discord.gg/SGwzd8PWPy
