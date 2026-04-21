# Play Billing – setup minimo Family Box

Obiettivo attuale:
- subscription annuale
- trial 3 mesi
- read only senza piano attivo

## 1. Crea il prodotto in Play Console
Monetize > Products > Subscriptions

Crea una subscription con:
- Product ID: `family_box_premium_annual`
- Nome: `Family Box Premium`

## 2. Base plan
Crea un base plan auto-rinnovabile:
- Base plan ID consigliato: `annual`
- Billing period: 1 anno

## 3. Trial
Aggiungi un'offerta introduttiva / free trial:
- Offer ID consigliato: `trial_3m`
- Durata trial: 3 mesi

## 4. Tester
Aggiungi l'account Google del telefono reale come tester in Play Console.

## 5. Track di test
Carica l'app almeno in una track di test Play (internal o closed).
Fuori dalla track, il catalogo Billing può risultare vuoto anche se il codice è corretto.

## 6. Coerenza config app
Nel progetto Flutter:
- `lib/config/billing_config.dart`

mantieni coerenti:
- productId
- basePlanId
- offerId

## 7. Limite attuale dell'implementazione
L'app aggiorna già l'entitlement dopo acquisto/restore,
ma la verifica server-side del token Play è il passo successivo prima della release finale.
