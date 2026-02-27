import 'package:equatable/equatable.dart';

import '../../MoForm/models/bom.dart';
import '../../MoForm/models/product.dart';
import '../../MoForm/models/user_model.dart';

/// State class for Create Manufacturing Order (MO) feature / screen
class CreateMOState extends Equatable {
  final bool isLoading;
  final bool isSuccess;
  final String errorMessage;
  final List<Product> products;
  final List<Bom> billOfMaterial;
  final List<UserModel> users;
  final List<dynamic> moveProducts;
  final List<dynamic> unbuildOrders;
  final List<dynamic> scrapProduct;

  const CreateMOState({
    required this.isLoading,
    required this.isSuccess,
    required this.errorMessage,
    required this.products,
    required this.billOfMaterial,
    required this.users,
    required this.moveProducts,
    required this.unbuildOrders,
    required this.scrapProduct,
  });

  /// Returns the initial / default state
  factory CreateMOState.initial() => const CreateMOState(
    isLoading: false,
    isSuccess: false,
    errorMessage: '',
    products: [],
    billOfMaterial: [],
    users: [],
    moveProducts: [],
    unbuildOrders: [],
    scrapProduct: [],
  );

  /// Creates a new state instance with some fields overridden
  CreateMOState copyWith({
    bool? isLoading,
    bool? isSuccess,
    String? errorMessage,
    List<Product>? products,
    List<Bom>? billOfMaterial,
    List<UserModel>? users,
    List<dynamic>? moveProducts,
    List<dynamic>? unbuildOrders,
    List<dynamic>? scrapProduct,
  }) {
    return CreateMOState(
      isLoading: isLoading ?? this.isLoading,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: errorMessage ?? this.errorMessage,
      products: products ?? this.products,
      billOfMaterial: billOfMaterial ?? this.billOfMaterial,
      users: users ?? this.users,
      moveProducts: moveProducts ?? this.moveProducts,
      unbuildOrders: unbuildOrders ?? this.unbuildOrders,
      scrapProduct: scrapProduct ?? this.scrapProduct,
    );
  }

  @override
  List<Object> get props => [
    isLoading,
    isSuccess,
    errorMessage,
    products,
    billOfMaterial,
    users,
    moveProducts,
    unbuildOrders,
    scrapProduct,
  ];
}