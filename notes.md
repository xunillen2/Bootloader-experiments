## Boot sekvenca

* Kada se računalo pali BIOS gleda za `boot signature`. `Boot signature` se nalazi u boot sektoru koji sadrži sekvence bajtova 0x55, 0xAA na pomaku 510 i 511. -> Tj. BIOS prihvati neki uređaj kao uređaj sa kojeg se računalo može pokretat ako je njegov boot sektor moguće pročitat i ako mu bajtovi na poziciji 510 i 511 jednaki 0x55AA.
* Ako je BIOS odluči da je uređaj validan za boot,čita prvih 512 bajtova i spema ih na memorijsku adresu 0x007C00, te prebacuje kontrolu programa na tu adresu (eip -> 0x007C00). -> Zbog Limitacije MBRa, i to je uglavnom first stage bootloader koji uglavnom ima posao da učitava i daje kontrolu nekom drugom većem bootloaderu (second stage).

### Real Mode

* Svi x86 procesori započinju izvršavanje u Real Modeu radi kompatibilnosti.
* **Prednosti**:
  * BIOS nam daje drivere sa kojima kontroliramo uređaje i prekide.
  * Imamo pristup listi low-level funkcija BIOSa
  * Pristup memoriji je brže zbog manjih registara i zbog nedostatka tablice dekstriptora 
* **Nedostaci**:
  * Imamo manje od 1MB memorije sa kojim možemo raditi -> U relanosti puno manje od 1MB
  * Nemamo hardversku zaštitu memorije (GDT - pogledaj) niti virtualnu memoriju
  * Nema zaštite 
  * Duljina operanda procesora je 16 bitna.
  * Adresiranje je teže nego u drugim modovima procesora
  * Za pristupanje više od 64k memorije treba koristit segmentne registre. 

* **Adresiranje memorije**: Pristupanje memoriji se radi preko segment:offset sistema. Gdje je segment jedan od 6 segmentnih registara, CS, DS, ES, FS, GS, SS korišten sa sljedečom notacijom: 12F3:4B27 (Segment:Offset). Tu se koristi slj. formula 'Fizička adresa = Segment * 16 + Offset'; pa prema tome 12F3:4B27 pokazuje na '12F3 * 16 + 4B27 = 17A57'
Note za mene: Postavi qemu nakon

### Informacije o segmentaciji

---
### Razni prekidi

#### Video

##### Scroll Down window

```
AH = 07h
AL = number of lines by which to scroll down (00h=clear entire window)
BH = attribute used to write blank lines at top of window - Određuje boju ekrana -> BIOS Color atribute
CH,CL = row,column of window's upper left corner - Definira koji je lijevi gornji kut ekrana
DH,DL = row,column of window's lower right corner - Definira koji je desni doljni kut  ekrana
```

##### Set cursor position

```
AH = 02h
BH = page number
0-3 in modes 2&3
0-7 in modes 0&1
0 in graphics modes
DH = row (00h is top)
DL = column (00h is left)
```

##### Teletype output

```
AH = 0Eh
AL = character to write
BH = page number
BL = foreground color (graphics modes only)

Piše slovo i pomiče pokazivač na ekranu (+1)
```

