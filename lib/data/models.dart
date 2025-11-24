enum CustomerTypeKind { b2b, b2c }

enum WorkTypeKind { installation, preventiveMaintenance, correctiveMaintenance }

enum JobOrderStatusKind { pending, inProgress, completed, cancelled }

enum PaymentMethodKind { cash, gcash, bankTransfer, card, cheque, other }

enum ExpenseCategoryKind { fuel, materials, food, transportation, toll, other }

class RoleData {
  final int id;
  final String role;

  const RoleData({required this.id, required this.role});
}

class UserData {
  final int id;
  final RoleData role;
  final String username;
  final String password;

  const UserData({
    required this.id,
    required this.role,
    required this.username,
    required this.password,
  });
}

class CustomerTypeData {
  final int id;
  final CustomerTypeKind type;

  const CustomerTypeData({required this.id, required this.type});
}

class CustomerData {
  final int id;
  final CustomerTypeData customerType;
  final String companyName;
  final String firstName;
  final String middleName;
  final String lastName;
  final String jobPosition;
  final String contactNumber;
  final String unitOrBuilding;
  final String street;
  final String subdivisionOrVillage;
  final String barangay;
  final String city;
  final String landmark;

  const CustomerData({
    required this.id,
    required this.customerType,
    required this.companyName,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.jobPosition,
    required this.contactNumber,
    required this.unitOrBuilding,
    required this.street,
    required this.subdivisionOrVillage,
    required this.barangay,
    required this.city,
    required this.landmark,
  });
}

class BrandData {
  final int id;
  final String name;

  const BrandData({required this.id, required this.name});
}

class AirconTypeData {
  final int id;
  final String typeName;

  const AirconTypeData({required this.id, required this.typeName});
}

class AirconData {
  final int id;
  final BrandData brand;
  final AirconTypeData airconType;
  final CustomerData customer;
  final String remarks;

  const AirconData({
    required this.id,
    required this.brand,
    required this.airconType,
    required this.customer,
    required this.remarks,
  });
}

class JobTypeData {
  final int id;
  final String jobType;

  const JobTypeData({required this.id, required this.jobType});
}

class JobStatusData {
  final int id;
  final String status;

  const JobStatusData({required this.id, required this.status});
}

class TechnicianData {
  final int id;
  final String firstName;
  final String middleName;
  final String lastName;
  final String contactNumber;

  const TechnicianData({
    required this.id,
    required this.firstName,
    required this.middleName,
    required this.lastName,
    required this.contactNumber,
  });
}

class JobOrderData {
  final int id;
  final JobTypeData jobType;
  final JobStatusData status;
  final UserData createdBy;
  final CustomerData customer;
  final String clientJoNumber;
  final DateTime dateCreated;
  final DateTime dateScheduled;
  final DateTime? dateCompleted;
  final CustomerTypeKind segment; // b2b or b2c
  final WorkTypeKind workType; // installation / PM / CM

  const JobOrderData({
    required this.id,
    required this.jobType,
    required this.status,
    required this.createdBy,
    required this.customer,
    required this.clientJoNumber,
    required this.dateCreated,
    required this.dateScheduled,
    this.dateCompleted,
    required this.segment,
    required this.workType,
  });
}

class ServiceItemData {
  final int id;
  final String itemName;
  final String itemType;
  final double price;

  const ServiceItemData({
    required this.id,
    required this.itemName,
    required this.itemType,
    required this.price,
  });
}

class JobOrderLineItemData {
  final int id;
  final JobOrderData jobOrder;
  final ServiceItemData serviceItem;
  final int quantity;
  final double actualPrice;

  const JobOrderLineItemData({
    required this.id,
    required this.jobOrder,
    required this.serviceItem,
    required this.quantity,
    required this.actualPrice,
  });
}

class JobOrderTechnicianData {
  final int id;
  final JobOrderData jobOrder;
  final TechnicianData technician;
  final String role;

  const JobOrderTechnicianData({
    required this.id,
    required this.jobOrder,
    required this.technician,
    required this.role,
  });
}

class JobOrderAirconData {
  final int id;
  final JobOrderData jobOrder;
  final AirconData aircon;

  const JobOrderAirconData({
    required this.id,
    required this.jobOrder,
    required this.aircon,
  });
}

class PaymentData {
  final int id;
  final JobOrderData jobOrder;
  final double amount;
  final DateTime paymentDate;
  final PaymentMethodKind paymentMethod;
  final String referenceNumber;
  final String orNumber;
  final String status; // e.g. Pending, Verified
  final String proofImageUrl;

  const PaymentData({
    required this.id,
    required this.jobOrder,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    required this.referenceNumber,
    required this.orNumber,
    required this.status,
    required this.proofImageUrl,
  });
}

class ExpenseData {
  final int id;
  final JobOrderData? jobOrder; // some expenses may be general
  final double amount;
  final DateTime paymentDate;
  final PaymentMethodKind paymentMethod;
  final String referenceNumber;
  final String orNumber;
  final String status;
  final String proofImageUrl;
  final ExpenseCategoryKind category;
  final bool isCustomerFunded;

  const ExpenseData({
    required this.id,
    this.jobOrder,
    required this.amount,
    required this.paymentDate,
    required this.paymentMethod,
    required this.referenceNumber,
    required this.orNumber,
    required this.status,
    required this.proofImageUrl,
    required this.category,
    required this.isCustomerFunded,
  });
}
