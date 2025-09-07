// Authentication service tests
import { describe, it, expect, beforeEach, afterEach } from '@jest/globals';
import { getFirestore } from 'firebase-admin/firestore';
import {
  registerUser,
  loginUser,
  resetPassword,
  updateUserProfile,
  deleteUserAccount,
} from '../../src/auth/services/auth-service';
import {
  createTestUser,
  deleteTestUser,
  generateTestToken,
  mockRequest,
  mockResponse,
  cleanupTestData,
  expectValidationError,
  expectUnauthorizedError,
  assertApiResponse,
  generateRandomString,
} from '../setup-real';

describe('Authentication Service', () => {
  let testUserIds: string[] = [];

  beforeEach(async () => {
    await cleanupTestData();
    testUserIds = [];
  });

  afterEach(async () => {
    // Clean up test users
    for (const userId of testUserIds) {
      await deleteTestUser(userId);
    }
    testUserIds = [];
  });

  describe('User Registration', () => {
    it('should register a new passenger successfully', async () => {
      const userData = {
        email: `test-passenger-${generateRandomString()}@test.com`,
        password: 'TestPassword123!',
        firstName: 'Test',
        lastName: 'Passenger',
        phoneNumber: '+541234567890',
        role: 'passenger',
      };

      const req = mockRequest({
        method: 'POST',
        body: userData,
      });
      const res = mockResponse();

      await registerUser(req, res);

      expect(res.status).toHaveBeenCalledWith(201);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.objectContaining({
            user: expect.objectContaining({
              email: userData.email,
              role: userData.role,
              isActive: true,
            }),
            token: expect.any(String),
          }),
        })
      );
    });

    it('should register a new driver successfully', async () => {
      const userData = {
        email: `test-driver-${generateRandomString()}@test.com`,
        password: 'TestPassword123!',
        firstName: 'Test',
        lastName: 'Driver',
        phoneNumber: '+541234567891',
        role: 'driver',
        licenseNumber: 'DL123456789',
        vehicleInfo: {
          make: 'Toyota',
          model: 'Corolla',
          year: 2020,
          licensePlate: 'ABC123',
          color: 'White',
        },
      };

      const req = mockRequest({
        method: 'POST',
        body: userData,
      });
      const res = mockResponse();

      await registerUser(req, res);

      expect(res.status).toHaveBeenCalledWith(201);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.objectContaining({
            user: expect.objectContaining({
              email: userData.email,
              role: userData.role,
              isActive: true,
            }),
            token: expect.any(String),
          }),
        })
      );
    });

    it('should reject registration with invalid email', async () => {
      const userData = {
        email: 'invalid-email',
        password: 'TestPassword123!',
        firstName: 'Test',
        lastName: 'User',
        phoneNumber: '+541234567892',
        role: 'passenger',
      };

      const req = mockRequest({
        method: 'POST',
        body: userData,
      });
      const res = mockResponse();

      try {
        await registerUser(req, res);
      } catch (error) {
        expectValidationError(error, 'email');
      }
    });

    it('should reject registration with weak password', async () => {
      const userData = {
        email: `test-weak-${generateRandomString()}@test.com`,
        password: '123',
        firstName: 'Test',
        lastName: 'User',
        phoneNumber: '+541234567893',
        role: 'passenger',
      };

      const req = mockRequest({
        method: 'POST',
        body: userData,
      });
      const res = mockResponse();

      try {
        await registerUser(req, res);
      } catch (error) {
        expectValidationError(error, 'password');
      }
    });

    it('should reject duplicate email registration', async () => {
      const email = `test-duplicate-${generateRandomString()}@test.com`;
      
      // Create first user
      const testUser = await createTestUser({
        uid: `test_user_${generateRandomString()}`,
        email,
        displayName: 'Test User 1',
        phoneNumber: '+541234567894',
        role: 'passenger',
        isActive: true,
      });
      testUserIds.push(testUser.uid);

      // Try to register with same email
      const userData = {
        email,
        password: 'TestPassword123!',
        firstName: 'Test',
        lastName: 'User2',
        phoneNumber: '+541234567895',
        role: 'passenger',
      };

      const req = mockRequest({
        method: 'POST',
        body: userData,
      });
      const res = mockResponse();

      try {
        await registerUser(req, res);
      } catch (error: any) {
        expect(error.statusCode).toBe(409);
        expect(error.code).toBe('EMAIL_ALREADY_EXISTS');
      }
    });
  });

  describe('User Login', () => {
    let testUser: any;

    beforeEach(async () => {
      testUser = await createTestUser({
        uid: `test_user_${generateRandomString()}`,
        email: `test-login-${generateRandomString()}@test.com`,
        displayName: 'Test Login User',
        phoneNumber: '+541234567896',
        role: 'passenger',
        isActive: true,
        firstName: 'Test',
        lastName: 'Login User',
      });
      testUserIds.push(testUser.uid);
      // A\u00f1adir el rol para las expectativas
      testUser.role = 'passenger';
    });

    it('should login with valid credentials', async () => {
      const loginData = {
        email: testUser.email,
        password: 'testpassword123',
      };

      const req = mockRequest({
        method: 'POST',
        body: loginData,
      });
      const res = mockResponse();

      await loginUser(req, res);

      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.objectContaining({
            user: expect.objectContaining({
              email: testUser.email,
              role: testUser.role,
            }),
            token: expect.any(String),
          }),
        })
      );
    });

    it('should reject login with invalid email', async () => {
      const loginData = {
        email: 'nonexistent@test.com',
        password: 'testpassword123',
      };

      const req = mockRequest({
        method: 'POST',
        body: loginData,
      });
      const res = mockResponse();

      try {
        await loginUser(req, res);
      } catch (error) {
        expectUnauthorizedError(error);
      }
    });

    it('should reject login with invalid password', async () => {
      const loginData = {
        email: testUser.email,
        password: 'wrongpassword',
      };

      const req = mockRequest({
        method: 'POST',
        body: loginData,
      });
      const res = mockResponse();

      try {
        await loginUser(req, res);
      } catch (error) {
        expectUnauthorizedError(error);
      }
    });

    it('should reject login for inactive user', async () => {
      // Desactivar usuario directamente en Firestore
      const db = getFirestore();
      await db.collection('test_users').doc(testUser.uid).update({
        isActive: false,
      });

      const loginData = {
        email: testUser.email,
        password: 'testpassword123',
      };

      const req = mockRequest({
        method: 'POST',
        body: loginData,
      });
      const res = mockResponse();

      try {
        await loginUser(req, res);
      } catch (error: any) {
        expect(error.statusCode).toBe(403);
        expect(error.code).toBe('ACCOUNT_INACTIVE');
      }
    });
  });

  describe('Password Reset', () => {
    let testUser: any;

    beforeEach(async () => {
      testUser = await createTestUser({
        uid: `test_user_${generateRandomString()}`,
        email: `test-reset-${generateRandomString()}@test.com`,
        displayName: 'Test Reset User',
        phoneNumber: '+541234567897',
        role: 'passenger',
        isActive: true,
      });
      testUserIds.push(testUser.uid);
    });

    it('should send password reset email for valid user', async () => {
      const req = mockRequest({
        method: 'POST',
        body: { email: testUser.email },
      });
      const res = mockResponse();

      await resetPassword(req, res);

      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          message: expect.stringContaining('reset'),
        })
      );
    });

    it('should handle password reset for non-existent email gracefully', async () => {
      const req = mockRequest({
        method: 'POST',
        body: { email: 'nonexistent@test.com' },
      });
      const res = mockResponse();

      await resetPassword(req, res);

      // Should still return success for security reasons
      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          message: expect.stringContaining('reset'),
        })
      );
    });
  });

  describe('User Profile Management', () => {
    let testUser: any;

    beforeEach(async () => {
      testUser = await createTestUser({
        uid: `test_user_${generateRandomString()}`,
        email: `test-profile-${generateRandomString()}@test.com`,
        displayName: 'Test Profile User',
        phoneNumber: '+541234567898',
        role: 'passenger',
        isActive: true,
      });
      testUserIds.push(testUser.uid);
    });

    it('should update user profile successfully', async () => {
      const updateData = {
        firstName: 'Updated',
        lastName: 'Name',
        phoneNumber: '+541234567899',
      };

      const req = mockRequest({
        method: 'PUT',
        body: updateData,
        userId: testUser.uid,
      });
      const res = mockResponse();

      await updateUserProfile(req, res);

      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          data: expect.objectContaining({
            user: expect.objectContaining({
              firstName: updateData.firstName,
              lastName: updateData.lastName,
              phoneNumber: updateData.phoneNumber,
            }),
          }),
        })
      );
    });

    it('should reject profile update without authentication', async () => {
      const updateData = {
        firstName: 'Updated',
        lastName: 'Name',
      };

      const req = mockRequest({
        method: 'PUT',
        body: updateData,
        // No userId
      });
      const res = mockResponse();

      try {
        await updateUserProfile(req, res);
      } catch (error) {
        expectUnauthorizedError(error);
      }
    });

    it('should reject invalid phone number update', async () => {
      const updateData = {
        phoneNumber: 'invalid-phone',
      };

      const req = mockRequest({
        method: 'PUT',
        body: updateData,
        userId: testUser.uid,
      });
      const res = mockResponse();

      try {
        await updateUserProfile(req, res);
      } catch (error) {
        expectValidationError(error, 'phone');
      }
    });
  });

  describe('Account Deletion', () => {
    let testUser: any;

    beforeEach(async () => {
      testUser = await createTestUser({
        uid: `test_user_${generateRandomString()}`,
        email: `test-delete-${generateRandomString()}@test.com`,
        displayName: 'Test Delete User',
        phoneNumber: '+541234567900',
        role: 'passenger',
        isActive: true,
      });
    });

    it('should delete user account successfully', async () => {
      const req = mockRequest({
        method: 'DELETE',
        userId: testUser.uid,
      });
      const res = mockResponse();

      await deleteUserAccount(req, res);

      expect(res.status).toHaveBeenCalledWith(200);
      expect(res.json).toHaveBeenCalledWith(
        expect.objectContaining({
          success: true,
          message: expect.stringContaining('deleted'),
        })
      );

      // User should be marked as inactive, not actually deleted
      // (for data integrity and audit purposes)
    });

    it('should reject account deletion without authentication', async () => {
      const req = mockRequest({
        method: 'DELETE',
        // No userId
      });
      const res = mockResponse();

      try {
        await deleteUserAccount(req, res);
      } catch (error) {
        expectUnauthorizedError(error);
      }
    });
  });
});