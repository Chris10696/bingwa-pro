import { Injectable } from '@nestjs/common';
import { ProductsService } from './products.service';
import { ProductType, ProductNetwork } from './entities/product.entity';

@Injectable()
export class ProductsSeed {
  constructor(private readonly productsService: ProductsService) {}

  async seed() {
    const safaricomAirtime = [
      { code: 'SAF_AIRTIME_10', name: 'Airtime KES 10', type: ProductType.AIRTIME, network: ProductNetwork.SAFARICOM, price: 10, value: 'KES 10', ussdCode: '*334#' },
      { code: 'SAF_AIRTIME_20', name: 'Airtime KES 20', type: ProductType.AIRTIME, network: ProductNetwork.SAFARICOM, price: 20, value: 'KES 20', ussdCode: '*334#' },
      { code: 'SAF_AIRTIME_50', name: 'Airtime KES 50', type: ProductType.AIRTIME, network: ProductNetwork.SAFARICOM, price: 50, value: 'KES 50', ussdCode: '*334#' },
      { code: 'SAF_AIRTIME_100', name: 'Airtime KES 100', type: ProductType.AIRTIME, network: ProductNetwork.SAFARICOM, price: 100, value: 'KES 100', ussdCode: '*334#' },
    ];

    const safaricomData = [
      { code: 'SAF_DATA_10MB', name: '10MB Daily', type: ProductType.DATA, network: ProductNetwork.SAFARICOM, price: 5, value: '10MB', validityDays: 1, ussdCode: '*544#' },
      { code: 'SAF_DATA_50MB', name: '50MB Daily', type: ProductType.DATA, network: ProductNetwork.SAFARICOM, price: 10, value: '50MB', validityDays: 1, ussdCode: '*544#' },
      { code: 'SAF_DATA_100MB', name: '100MB Daily', type: ProductType.DATA, network: ProductNetwork.SAFARICOM, price: 20, value: '100MB', validityDays: 1, ussdCode: '*544#' },
      { code: 'SAF_DATA_500MB', name: '500MB Weekly', type: ProductType.DATA, network: ProductNetwork.SAFARICOM, price: 100, value: '500MB', validityDays: 7, ussdCode: '*544#' },
      { code: 'SAF_DATA_1GB', name: '1GB Weekly', type: ProductType.DATA, network: ProductNetwork.SAFARICOM, price: 200, value: '1GB', validityDays: 7, ussdCode: '*544#' },
      { code: 'SAF_DATA_3GB', name: '3GB Monthly', type: ProductType.DATA, network: ProductNetwork.SAFARICOM, price: 500, value: '3GB', validityDays: 30, ussdCode: '*544#' },
    ];

    const safaricomSms = [
      { code: 'SAF_SMS_100', name: '100 SMS Daily', type: ProductType.SMS, network: ProductNetwork.SAFARICOM, price: 20, value: '100 SMS', validityDays: 1, ussdCode: '*544#' },
      { code: 'SAF_SMS_500', name: '500 SMS Weekly', type: ProductType.SMS, network: ProductNetwork.SAFARICOM, price: 80, value: '500 SMS', validityDays: 7, ussdCode: '*544#' },
    ];

    const allProducts = [...safaricomAirtime, ...safaricomData, ...safaricomSms];
    
    for (const product of allProducts) {
      try {
        await this.productsService.createProduct(product);
        console.log(`Created product: ${product.name}`);
      } catch (error) {
        console.log(`Product ${product.name} already exists, skipping`);
      }
    }
  }
}