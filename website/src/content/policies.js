import { CONTACT_EMAIL } from '../config';

/**
 * Policy texts. They describe what the IronRank app actually does (see the
 * backend and app code). Review them, and have them checked if you
 * publish commercially — this is a starting point, not legal advice.
 *
 * Each section: { id, heading, body: [paragraph | { list: [...] }] }
 */
export const LAST_UPDATED = 'October 15, 2026';

export const policies = {
  privacy: {
    title: 'Privacy Policy',
    tagline: 'What IronRank stores, why, and how you stay in control.',
    sections: [
      {
        id: 'summary',
        heading: 'The short version',
        body: [
          {
            list: [
              'We only collect what the app needs to track your training: your account, your profile, your workouts and the food you log.',
              'We never sell your data and the app shows no ads.',
              'Passwords are stored hashed (bcrypt) — never in plain text.',
              'You can ask us to export or delete your data at any time.',
            ],
          },
        ],
      },
      {
        id: 'collect',
        heading: 'Information we collect',
        body: [
          'When you use IronRank we store:',
          {
            list: [
              'Account details: your email address, username and a hashed password.',
              'Profile details you choose to enter: sex, birth date, height, bodyweight (and its history), unit preference, activity level, goal and rest-timer preference.',
              'Training data: workouts, sets, weights, reps, RPE, rest times, notes, programs and custom exercises you create.',
              'Results we calculate from your data: personal records, strength ranks, statistics and calorie estimates.',
              'Nutrition data: food entries (name, calories and macros) and your daily calorie target.',
              'Technical data needed to keep you signed in: securely stored sign-in tokens. Our server may keep standard request logs (such as IP address and time) for security and troubleshooting.',
            ],
          },
          'We do not collect your location, contacts, photos or advertising identifiers.',
        ],
      },
      {
        id: 'use',
        heading: 'How we use it',
        body: [
          {
            list: [
              'To provide the app: save and sync your workouts, show your history and progress.',
              'To calculate features you see: personal records, estimated one-rep max, strength ranks (which compare your lifts to your bodyweight and sex-specific standards), calories burned and calorie targets (which use your age, sex, height, weight and activity level).',
              'To keep your account secure and the service running.',
            ],
          },
          'We do not use your data for advertising, and we do not build profiles to sell.',
        ],
      },
      {
        id: 'device',
        heading: 'Data stored on your phone',
        body: [
          'To make workouts offline-safe, the app keeps your in-progress workout, workouts waiting to sync and a cache of recent data on your device. Sign-in tokens are kept in your phone’s secure storage (Keychain / Keystore). Signing out removes this data from the device.',
          'Rest-timer alerts are local notifications scheduled on your phone; they are not sent through our servers.',
        ],
      },
      {
        id: 'sharing',
        heading: 'Sharing and service providers',
        body: [
          'We don’t sell or rent your personal data. We only share it with providers that help us run IronRank, under their own security commitments:',
          {
            list: [
              'Hosting for our API server (Render).',
              'Database hosting for your account and training data (MongoDB).',
              'Exercise images are loaded from the public free-exercise-db repository on GitHub; loading an image reveals your IP address to GitHub, like visiting any website.',
            ],
          },
          'We may disclose information if required by law or to protect the safety of users.',
        ],
      },
      {
        id: 'security',
        heading: 'Security',
        body: [
          'Connections to our API are encrypted (HTTPS). Passwords are hashed with bcrypt. Sign-in uses short-lived access tokens and rotating refresh tokens, and a reused refresh token signs out the whole session family. No system is perfectly secure, but we work to protect your data and fix issues quickly.',
        ],
      },
      {
        id: 'retention',
        heading: 'Retention and your choices',
        body: [
          'We keep your data while your account exists. You can edit your profile, delete workouts, food entries and custom exercises in the app at any time.',
          `To export your data or delete your account and all associated data, email ${CONTACT_EMAIL}. We’ll respond within 30 days. Depending on where you live (for example under the GDPR), you may also have rights to access, correct, restrict or object to processing, and to complain to a data-protection authority.`,
        ],
      },
      {
        id: 'children',
        heading: 'Children',
        body: ['IronRank is not intended for children under 13, and we do not knowingly collect their data. If you believe a child has created an account, contact us and we’ll delete it.'],
      },
      {
        id: 'changes',
        heading: 'Changes and contact',
        body: [
          'If we change this policy we’ll update the date above, and for significant changes we’ll let you know in the app.',
          `Questions? Email ${CONTACT_EMAIL}.`,
        ],
      },
    ],
  },

  terms: {
    title: 'Terms of Use',
    tagline: 'The rules for using IronRank — written to be read.',
    sections: [
      {
        id: 'agreement',
        heading: 'Agreement',
        body: ['By downloading or using IronRank you agree to these terms. If you don’t agree, please don’t use the app.'],
      },
      {
        id: 'account',
        heading: 'Your account',
        body: [
          {
            list: [
              'You must be at least 13 years old to create an account.',
              'Give accurate information and keep your password secure — you’re responsible for activity on your account.',
              'Tell us right away if you think your account has been accessed without permission.',
            ],
          },
        ],
      },
      {
        id: 'license',
        heading: 'License to use the app',
        body: [
          'We give you a personal, non-exclusive, non-transferable license to install and use IronRank for your own training. Please don’t copy, resell, reverse-engineer or redistribute the app, and only download it from this website or other official sources we publish.',
          'Installing the Android app from this website (outside an app store) requires allowing installs from your browser. Only do so for files downloaded from our official link.',
        ],
      },
      {
        id: 'acceptable-use',
        heading: 'Acceptable use',
        body: [
          'Don’t misuse the service: no attempts to break into accounts or systems, overload or disrupt the API, scrape data at scale, or use IronRank for anything illegal.',
        ],
      },
      {
        id: 'content',
        heading: 'Your content',
        body: [
          'Your workouts, programs, custom exercises and notes are yours. You give us permission to store and process them only so we can provide the app to you. Exercise descriptions and images in the built-in library come from the public-domain free-exercise-db project.',
        ],
      },
      {
        id: 'health',
        heading: 'Not medical advice',
        body: [
          'IronRank is a training log, not a medical device. Strength ranks, one-rep-max estimates, calories burned and calorie targets are estimates. See the Health Disclaimer for details.',
        ],
      },
      {
        id: 'availability',
        heading: 'Availability and changes',
        body: [
          'We work hard to keep IronRank running, but the service is provided “as is” and may occasionally be unavailable (for example while the server wakes up or during maintenance). We may change or discontinue features; if we ever shut the service down we’ll give reasonable notice so you can request your data.',
        ],
      },
      {
        id: 'liability',
        heading: 'Disclaimer and limitation of liability',
        body: [
          'To the fullest extent permitted by law, IronRank is provided without warranties of any kind, and we are not liable for indirect, incidental or consequential damages, or for injuries resulting from exercise or diet decisions you make. Nothing in these terms limits rights you have under consumer law that can’t be limited.',
        ],
      },
      {
        id: 'termination',
        heading: 'Ending your use',
        body: [`You can stop using IronRank at any time and ask us to delete your account at ${CONTACT_EMAIL}. We may suspend accounts that break these terms.`],
      },
      {
        id: 'contact',
        heading: 'Changes and contact',
        body: [`We may update these terms; the date above shows the latest version. Continued use means you accept the changes. Contact: ${CONTACT_EMAIL}.`],
      },
    ],
  },

  disclaimer: {
    title: 'Health Disclaimer',
    tagline: 'Train hard, train smart — and listen to your body.',
    sections: [
      {
        id: 'not-medical',
        heading: 'Not medical advice',
        body: [
          'IronRank provides tools to log training and nutrition. It does not provide medical, nutritional or physical-therapy advice, and it is not a substitute for a doctor, registered dietitian or qualified coach.',
        ],
      },
      {
        id: 'estimates',
        heading: 'All numbers are estimates',
        body: [
          {
            list: [
              'Estimated one-rep max uses the Epley formula and is less accurate for higher-rep sets.',
              'Calories burned use MET values × your bodyweight × active time — real expenditure varies a lot between people.',
              'Calorie targets use the Mifflin-St Jeor equation with an activity factor; they are starting points, not prescriptions.',
              'Strength ranks compare your lifts to general population standards and say nothing about your health.',
            ],
          },
        ],
      },
      {
        id: 'consult',
        heading: 'Check with a professional',
        body: [
          'Talk to a doctor before starting a new training or diet program — especially if you are pregnant, have a medical condition, an injury, or take medication. Stop exercising and seek help if you feel pain, dizziness, shortness of breath or chest discomfort.',
        ],
      },
      {
        id: 'responsibility',
        heading: 'Your responsibility',
        body: [
          'Use proper technique, warm up, use spotters or safety equipment for heavy lifts, and choose weights you can handle safely. You train at your own risk.',
        ],
      },
    ],
  },
};

export const policyOrder = ['privacy', 'terms', 'disclaimer'];
