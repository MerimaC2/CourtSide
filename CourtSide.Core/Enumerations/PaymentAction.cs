namespace CourtSide.Core.Enumerations;

/// <summary>What is being attempted on a reservation's payment.</summary>
public enum PaymentAction
{
    /// <summary>Administrator records that cash was collected on-site.</summary>
    CollectCash = 1,

    /// <summary>Client starts (or resumes) an online card payment.</summary>
    StartOnlinePayment = 2,

    /// <summary>Money already collected is given back.</summary>
    Refund = 3,

    /// <summary>Administrator confirms that cash was physically handed back.</summary>
    ConfirmCashRefund = 4
}

/// <summary>Result of checking an action against the payment rules.</summary>
public enum PolicyOutcome
{
    /// <summary>The action is permitted.</summary>
    Allowed = 1,

    /// <summary>Nothing to do — not an error, but no effect either (e.g. refunding an unpaid booking).</summary>
    NoOp = 2,

    /// <summary>The action is not permitted in this combination of states.</summary>
    Denied = 3
}
