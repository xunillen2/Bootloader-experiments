## Boot sekvenca

* Kada se računalo pali BIOS gleda za `boot signature`. `Boot signature` se nalazi u boot sektoru koji sadrži sekvence bajtova 0x55, 0xAA na pomaku 510 i 511. -> Tj. BIOS prihvati neki uređaj kao uređaj sa kojeg se može pokretat ako je njegov boot sektor moguće pročitat i ako mu bajtovi na 510 i 511 jednaki 0x55AA.
* Ako je BIOS odluči da je uređaj validan za boot,čita prvih 512 bajtova i spema ih na memorijsku adresu 0x007C00, te prebacuje kontrolu programa na tu adresu (eip -> 0x007C00).

Note za mene: Postavi qemu nakon
