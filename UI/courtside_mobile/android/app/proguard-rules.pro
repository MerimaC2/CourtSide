# Stripe push provisioning (izdavanje kartica) se ne koristi u aplikaciji; te opcione
# klase ne postoje u flutter_stripe paketu pa R8 ne smije pasti zbog referenci na njih.
-dontwarn com.stripe.android.pushProvisioning.**
