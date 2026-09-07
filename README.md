# Hitobito Florist

This hitobito wagon defines the organization hierarchy with groups and roles
of Florist.


## Florist Organization Hierarchy

<!-- roles:start -->
    * Dachverband
      * Dachverband
        * Administrator:in: [:admin, :layer_and_below_full, :finance, :approve_applications, :impersonation]
        * Mitarbeiter:in: [:admin, :layer_and_below_full, :finance, :approve_applications]
      * Kontakte
        * Kontakt: []
      * Abonnemente
        * Jahresabo Schweiz: []
        * Jahresabo Mitglied: []
        * Jahresabo Europa: []
        * Probeabo: []
        * Lehrlingsabo: []
        * Gratisabo: []
        * Lehrgang Floristik: []
        * BM-plus: []
    * Sektion < Dachverband
      * Sektion
        * Aktivmitglied: []
        * Berufsmitglied: []
        * Berufsmitglied plus: []
        * StartUp: []
        * Ehrenmitglied: []
        * Filiale: []
        * Entdecker: []
        * Partnermitglied: []
        * Passivmitglied: []
        * Ex Mitglied: []

(Output of rake app:hitobito:roles)
<!-- roles:end -->