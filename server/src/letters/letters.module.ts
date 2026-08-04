import { Module } from '@nestjs/common';
import { AddressesService } from './addresses.service';
import { LettersController } from './letters.controller';
import { LettersService } from './letters.service';

@Module({
  controllers: [LettersController],
  providers: [LettersService, AddressesService],
})
export class LettersModule {}
